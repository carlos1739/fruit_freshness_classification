from __future__ import annotations

import io
import json
import os
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from PIL import Image, UnidentifiedImageError
from huggingface_hub import hf_hub_download


PROJECT_ROOT = Path(__file__).resolve().parent.parent
MODEL_FILENAME = "models/model_terbaik.keras"
MODEL_INFO_FILENAME = "models/model_terbaik_info.json"
STATIC_PATH = Path(__file__).resolve().parent / "static"
IMAGE_SIZE = (224, 224)
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 20_000_000
TOP_K = 3


def resolve_model_assets() -> tuple[Path, Path]:
    model_path = PROJECT_ROOT / MODEL_FILENAME
    info_path = PROJECT_ROOT / MODEL_INFO_FILENAME
    if model_path.is_file() and info_path.is_file():
        return model_path, info_path

    repo_id = os.environ.get(
        "MODEL_REPO_ID",
        "Carlos-leo/klasifikasi-kesegaran-buah",
    )
    repo_type = os.environ.get("MODEL_REPO_TYPE", "space")
    token = os.environ.get("HF_TOKEN")
    model_path = Path(
        hf_hub_download(
            repo_id=repo_id,
            filename=MODEL_FILENAME,
            repo_type=repo_type,
            token=token,
            local_dir=PROJECT_ROOT,
        )
    )
    info_path = Path(
        hf_hub_download(
            repo_id=repo_id,
            filename=MODEL_INFO_FILENAME,
            repo_type=repo_type,
            token=token,
            local_dir=PROJECT_ROOT,
        )
    )
    return model_path, info_path


def load_model_assets() -> tuple[tf.keras.Model, dict[int, str], dict[str, Any]]:
    model_path, info_path = resolve_model_assets()

    with info_path.open(encoding="utf-8") as file:
        info = json.load(file)

    class_names = {
        int(index): str(name) for index, name in info["nama_kelas"].items()
    }
    if not class_names or sorted(class_names) != list(range(len(class_names))):
        raise ValueError("Model class indices must be contiguous and start at zero.")

    model = tf.keras.models.load_model(model_path, compile=False)
    if model.input_shape[1:] != (*IMAGE_SIZE, 3):
        raise ValueError(
            f"Expected model input shape (None, {IMAGE_SIZE[0]}, "
            f"{IMAGE_SIZE[1]}, 3), got {model.input_shape}."
        )
    if model.output_shape[-1] != len(class_names):
        raise ValueError(
            "The number of model outputs does not match the class metadata."
        )
    return model, class_names, info


@asynccontextmanager
async def lifespan(app: FastAPI):
    model, class_names, info = load_model_assets()
    app.state.model = model
    app.state.class_names = class_names
    app.state.model_info = info
    yield


app = FastAPI(
    title="Fruit Freshness Classification API",
    description="Predicts fruit type and freshness from an uploaded image.",
    version="1.0.0",
    lifespan=lifespan,
)

allowed_origins = [
    origin.strip()
    for origin in os.environ.get(
        "CORS_ORIGINS",
        "http://localhost:5000,http://127.0.0.1:5000,"
        "http://localhost:8080,http://127.0.0.1:8080",
    ).split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/api/health")
async def health() -> dict[str, Any]:
    model_info = getattr(app.state, "model_info", None)
    if model_info is None:
        raise HTTPException(status_code=503, detail="Model is not ready.")
    return {
        "status": "ok",
        "model": model_info.get("percobaan", "Fruit classifier"),
        "validation_accuracy": model_info.get("akurasi_val"),
    }


@app.post("/api/predict")
async def predict(file: UploadFile = File(...)) -> dict[str, Any]:
    contents = await file.read(MAX_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded file is empty.")
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Image must be 10 MB or smaller.",
        )

    try:
        with Image.open(io.BytesIO(contents)) as image:
            if image.width * image.height > MAX_IMAGE_PIXELS:
                raise HTTPException(
                    status_code=413,
                    detail="Image dimensions are too large to process.",
                )
            image.load()
            pixels = np.asarray(image.convert("RGB"), dtype=np.uint8).copy()
    except HTTPException:
        raise
    except (UnidentifiedImageError, Image.DecompressionBombError, OSError) as error:
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a supported image.",
        ) from error

    resized = tf.image.resize(pixels, IMAGE_SIZE)
    resized = tf.cast(tf.round(resized), tf.uint8)
    batch = tf.cast(resized[tf.newaxis, ...], tf.float32) / 255.0
    probabilities = app.state.model(batch, training=False).numpy()[0]

    if probabilities.shape != (len(app.state.class_names),):
        raise ValueError("Model prediction shape does not match its class metadata.")

    indices = np.argsort(probabilities)[::-1][:TOP_K]
    return {
        "model": app.state.model_info.get("percobaan", "Fruit classifier"),
        "validation_accuracy": app.state.model_info.get("akurasi_val"),
        "top_predictions": [
            {
                "class_name": app.state.class_names[int(index)],
                "confidence": float(probabilities[index]),
            }
            for index in indices
        ],
    }


if STATIC_PATH.is_dir():
    app.mount("/", StaticFiles(directory=STATIC_PATH, html=True), name="frontend")

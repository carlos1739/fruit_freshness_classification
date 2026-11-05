import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import express from "express";
import multer from "multer";
import sharp from "sharp";
import * as tf from "@tensorflow/tfjs";
import cors from "cors";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MODEL_DIR = path.resolve(
  process.env.TFJS_MODEL_DIR ?? path.join(ROOT, "models", "model_tfjs"),
);
const INFO_PATH = path.join(ROOT, "models", "model_terbaik_info.json");
const IMAGE_SIZE = 224;
const MAX_UPLOAD_BYTES = 10 * 1024 * 1024;
const MAX_IMAGE_PIXELS = 20_000_000;
const TOP_K = 3;

const app = express();
const allowedOrigins = (process.env.CORS_ORIGINS ?? "*")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);
app.use(
  cors({
    origin: allowedOrigins.includes("*") ? true : allowedOrigins,
    methods: ["GET", "POST"],
  }),
);
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_UPLOAD_BYTES },
});

let classifier;

async function loadTfjsModel() {
  const modelJson = JSON.parse(
    await fs.readFile(path.join(MODEL_DIR, "model.json"), "utf8"),
  );
  const modelTopology = modelJson.modelTopology;
  const layers = modelTopology?.model_config?.config?.layers;
  if (Array.isArray(layers)) {
    for (const layer of layers) {
      if (
        layer.class_name === "InputLayer" &&
        layer.config?.batch_shape &&
        !layer.config.batchInputShape
      ) {
        layer.config.batchInputShape = layer.config.batch_shape;
        delete layer.config.batch_shape;
      }
    }
  }
  const weightSpecs = modelJson.weightsManifest.flatMap((manifest) =>
    manifest.weights,
  );
  const weightBuffers = await Promise.all(
    modelJson.weightsManifest.flatMap((manifest) =>
      manifest.paths.map((weightPath) =>
        fs.readFile(path.join(MODEL_DIR, weightPath)),
      ),
    ),
  );
  const weightData = Buffer.concat(weightBuffers);
  const model = await tf.loadLayersModel(
    tf.io.fromMemory({
      modelTopology,
      weightSpecs,
      weightData,
    }),
  );

  if (
    model.inputs[0].shape.join(",") !==
    [null, IMAGE_SIZE, IMAGE_SIZE, 3].join(",")
  ) {
    throw new Error(`Unexpected model input shape: ${model.inputs[0].shape}`);
  }
  return model;
}

async function loadAssets() {
  const info = JSON.parse(await fs.readFile(INFO_PATH, "utf8"));
  const classNames = Object.entries(info.nama_kelas).map(([index, name]) => ({
    index: Number(index),
    name: String(name),
  }));
  if (
    classNames.length === 0 ||
    classNames.some((item, index) => item.index !== index)
  ) {
    throw new Error("Model class indices must be contiguous and start at zero.");
  }
  classifier = {
    model: await loadTfjsModel(),
    classNames,
    info,
  };
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

app.get("/api/health", (_request, response) => {
  if (!classifier) {
    return response.status(503).json({ detail: "Model is not ready." });
  }
  return response.json({
    status: "ok",
    model: classifier.info.percobaan ?? "Fruit classifier",
    validation_accuracy: classifier.info.akurasi_val,
  });
});

app.post("/api/predict", upload.single("file"), async (request, response) => {
  if (!request.file?.buffer?.length) {
    return response.status(400).json({ detail: "The uploaded file is empty." });
  }

  try {
    const metadata = await sharp(request.file.buffer).metadata();
    if (
      Number.isFinite(metadata.width) &&
      Number.isFinite(metadata.height) &&
      metadata.width * metadata.height > MAX_IMAGE_PIXELS
    ) {
      return response
        .status(413)
        .json({ detail: "Image dimensions are too large to process." });
    }

    const { data } = await sharp(request.file.buffer)
      .toColourspace("srgb")
      .removeAlpha()
      .resize({
        width: IMAGE_SIZE,
        height: IMAGE_SIZE,
        fit: "fill",
        kernel: sharp.kernel.linear,
      })
      .raw()
      .toBuffer({ resolveWithObject: true });

    const probabilities = tf.tidy(() => {
      const input = tf.tensor4d(
        Array.from(data, (value) => Math.round(value) / 255),
        [1, IMAGE_SIZE, IMAGE_SIZE, 3],
        "float32",
      );
      return classifier.model.predict(input).dataSync();
    });
    if (probabilities.length !== classifier.classNames.length) {
      throw new Error("Model output does not match class metadata.");
    }

    const indices = Array.from(probabilities.keys())
      .sort((left, right) => probabilities[right] - probabilities[left])
      .slice(0, TOP_K);
    return response.json({
      model: classifier.info.percobaan ?? "Fruit classifier",
      validation_accuracy: classifier.info.akurasi_val,
      top_predictions: indices.map((index) => ({
        class_name: classifier.classNames[index].name,
        confidence: Number(probabilities[index]),
      })),
    });
  } catch (error) {
    return response
      .status(400)
      .json({ detail: `The uploaded file is not a supported image: ${errorMessage(error)}` });
  }
});

app.use((error, _request, response, _next) => {
  if (error instanceof multer.MulterError && error.code === "LIMIT_FILE_SIZE") {
    return response
      .status(413)
      .json({ detail: "Image must be 10 MB or smaller." });
  }
  return response.status(400).json({ detail: errorMessage(error) });
});

const port = Number(process.env.PORT ?? 7860);
const host = process.env.HOST ?? "0.0.0.0";

loadAssets()
  .then(() => {
    app.listen(port, host, () => {
      console.log(`Fruit API listening on http://${host}:${port}`);
    });
  })
  .catch((error) => {
    console.error(`Unable to load model assets: ${errorMessage(error)}`);
    process.exitCode = 1;
  });

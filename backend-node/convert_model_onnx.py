"""Convert the MobileNetV2 Keras checkpoint to ONNX for CPU-only inference."""

from pathlib import Path
import shutil
import subprocess
import sys

import tensorflow as tf


ROOT = Path(__file__).resolve().parent.parent
source = ROOT / "models" / "model_mobilenet.keras"
saved_model = ROOT / "models" / "_mobilenet_saved"
output = ROOT / "models" / "model_mobilenet.onnx"

if not source.exists():
    raise FileNotFoundError(f"MobileNetV2 checkpoint not found: {source}")
if saved_model.exists():
    shutil.rmtree(saved_model)

model = tf.keras.models.load_model(source, compile=False)
model.export(
    saved_model,
    input_signature=[
        tf.TensorSpec((None, 224, 224, 3), tf.float32, name="input")
    ],
)
subprocess.run(
    [
        sys.executable,
        "-m",
        "tf2onnx.convert",
        "--saved-model",
        str(saved_model),
        "--output",
        str(output),
        "--opset",
        "13",
    ],
    check=True,
)
shutil.rmtree(saved_model)
print(f"Converted MobileNetV2 to {output}")

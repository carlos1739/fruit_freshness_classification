"""Convert the Keras checkpoint to TensorFlow.js format.

Run this on a machine where TensorFlow can load the checkpoint. The VPS with
the current QEMU CPU cannot run the existing TensorFlow binary.
"""

from pathlib import Path

import tensorflow as tf
import tensorflowjs as tfjs


ROOT = Path(__file__).resolve().parent.parent
model = tf.keras.models.load_model(ROOT / "models" / "model_terbaik.keras", compile=False)
tfjs.converters.save_keras_model(model, str(ROOT / "models" / "model_tfjs"))
print("Converted model to models/model_tfjs")

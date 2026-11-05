"""Convert the Keras checkpoint to TensorFlow.js format.

Run this on a machine where TensorFlow can load the checkpoint. The VPS with
the current QEMU CPU cannot run the existing TensorFlow binary.
"""

from pathlib import Path
import sys
import types

import tensorflow as tf

# tensorflowjs imports optional SavedModel/JAX integrations eagerly. They are
# not needed for this Keras checkpoint and their Windows dependencies conflict
# with the local TensorFlow installation.
sys.modules.setdefault(
    "tensorflow_decision_forests", types.ModuleType("tensorflow_decision_forests")
)
sys.modules["tensorflow_hub"] = types.ModuleType("tensorflow_hub")

import tensorflowjs as tfjs


ROOT = Path(__file__).resolve().parent.parent
model = tf.keras.models.load_model(ROOT / "models" / "model_terbaik.keras", compile=False)
tfjs.converters.save_keras_model(model, str(ROOT / "models" / "model_tfjs"))
print("Converted model to models/model_tfjs")

"""Convert the Keras checkpoint to TensorFlow.js format.

Run this on a machine where TensorFlow can load the checkpoint. The VPS with
the current QEMU CPU cannot run the existing TensorFlow binary.
"""

from pathlib import Path
import json
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

output_dir = ROOT / "models" / "model_tfjs"
tfjs.converters.save_keras_model(model, str(output_dir))


def keras_tensor_history(value):
    if not isinstance(value, dict):
        return None
    config = value.get("config", {})
    history = config.get("keras_history")
    if isinstance(history, list) and len(history) == 3:
        return [history[0], history[1], history[2], {}]
    return None


def normalize_topology(value):
    if isinstance(value, list):
        return [normalize_topology(item) for item in value]
    if not isinstance(value, dict):
        return value

    normalized = {key: normalize_topology(item) for key, item in value.items()}
    config = normalized.get("config")
    if normalized.get("class_name") == "InputLayer" and isinstance(config, dict):
        if "batch_shape" in config and "batchInputShape" not in config:
            config["batchInputShape"] = config.pop("batch_shape")

    inbound_nodes = normalized.get("inbound_nodes")
    if isinstance(inbound_nodes, list):
        converted_nodes = []
        for node in inbound_nodes:
            if not isinstance(node, dict):
                converted_nodes.append(node)
                continue
            connections = []
            for argument in node.get("args", []):
                history = keras_tensor_history(argument)
                if history is not None:
                    connections.append(history)
            converted_nodes.append(connections)
        normalized["inbound_nodes"] = converted_nodes
    return normalized


model_json_path = output_dir / "model.json"
model_json = json.loads(model_json_path.read_text(encoding="utf-8"))
model_json["modelTopology"] = normalize_topology(model_json["modelTopology"])
model_json_path.write_text(
    json.dumps(model_json, ensure_ascii=False),
    encoding="utf-8",
)
print("Converted model to models/model_tfjs")

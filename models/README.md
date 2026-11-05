# Model artifacts

The notebook writes `model_terbaik.keras` and `model_terbaik_info.json` here.
The best recorded experiment is MobileNetV2 Transfer Learning with validation
accuracy `0.945263147354126` and test accuracy `0.9411`.

The deployment backend uses `model_mobilenet.onnx`, generated from the
MobileNetV2 Keras checkpoint with `backend-node/convert_model_onnx.py`. Large
model files should be managed with Git LFS or copied to the API host using the
deployment procedure in the root README.

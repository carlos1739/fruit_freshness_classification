# Node.js backend

This backend keeps the same API contract as the Python backend:

- `GET /api/health`
- `POST /api/predict` with multipart field `file`

Node.js cannot load `models/model_mobilenet.keras` directly. Convert it once on a
machine that can run TensorFlow:

```powershell
python -m pip install tensorflow==2.21.0 tf2onnx==1.17.0
python backend-node/convert_model_onnx.py
cd backend-node
npm install
npm start
```

The conversion creates `models/model_mobilenet.onnx`. Deploy this file with the
Node.js service. ONNX Runtime is used because the VPS CPU cannot run native
TensorFlow binaries.

Configuration:

- `PORT` defaults to `7860`.
- `HOST` defaults to `0.0.0.0`.
- `CORS_ORIGINS` is a comma-separated allowlist; it defaults to allowing all
  origins for initial testing.

The API always returns the three highest-scoring predictions without a minimum
confidence threshold. The model was trained only on fruit classes, so a
non-fruit image can still receive a fruit label; low confidence alone does not
prove that an image is not fruit.

# Node.js backend

This backend keeps the same API contract as the Python backend:

- `GET /api/health`
- `POST /api/predict` with multipart field `file`

Node.js cannot load `models/model_terbaik.keras` directly. Convert it once on a
machine that can run TensorFlow:

```powershell
python -m pip install tensorflow tensorflowjs
python backend-node/convert_model.py
cd backend-node
npm install
npm start
```

The conversion creates `models/model_tfjs/model.json` and weight shards. These
files must be deployed with the Node.js service. The current VPS CPU cannot
perform the conversion or run the original TensorFlow checkpoint because it
does not expose AVX/AVX2 instructions.

Configuration:

- `PORT` defaults to `7860`.
- `HOST` defaults to `0.0.0.0`.
- `TFJS_MODEL_DIR` can point to another converted model directory.
- `CORS_ORIGINS` is a comma-separated allowlist; it defaults to allowing all
  origins for initial testing.

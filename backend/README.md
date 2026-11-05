# Backend

FastAPI loads `models/model_terbaik.keras` once when the application starts.

- `GET /api/health`: reports readiness and the checkpoint's validation accuracy.
- `POST /api/predict`: accepts an image as multipart form field `file` and returns the three most likely classes.

The API uses the notebook's image preprocessing: RGB, resize to 224x224, round to uint8, then divide pixels by 255.

For local development, install `requirements.txt` from the repository root and run:

```powershell
python -m pip install -r backend/requirements.txt
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 7860
```

The API expects the trained model and its `model_terbaik_info.json` metadata in the root `models/` directory.

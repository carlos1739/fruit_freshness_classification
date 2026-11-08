# Flutter Web frontend

The frontend lets a user choose a fruit image, uploads it to the Node.js
backend, and displays the model's three most likely classes.

The web app also provides a real dataset example for a live API prediction,
mobile-browser camera capture, CSV report download, local prediction history,
model details (224x224 RGB input with three channels), API health status, reset
controls, and photo-taking tips. History stores filenames and prediction
results in browser storage, not the uploaded image. Batch image prediction is
not supported.

Hugging Face Static Space serves the compiled Flutter app, and the API is hosted
separately. For local development:

1. Start the API from the repository root on port 7860.
2. Run `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:7860`.

Run `flutter analyze`, `flutter test`, and `flutter build web --release
--base-href /` from this directory to validate the frontend.

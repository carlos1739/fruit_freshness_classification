# Flutter Web frontend

The frontend lets a user choose a fruit image, uploads it to the Node.js
backend, and displays the model's three most likely classes.

Hugging Face Static Space serves the compiled Flutter app, and the API is hosted
separately. For local development:

1. Start the API from the repository root on port 7860.
2. Run `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:7860`.

Run `flutter analyze`, `flutter test`, and `flutter build web --release
--base-href /` from this directory to validate the frontend.

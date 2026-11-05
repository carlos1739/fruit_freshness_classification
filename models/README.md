# Model artifacts

The notebook writes `model_terbaik.keras` and `model_terbaik_info.json` here.
The Keras checkpoint is tracked with Git LFS so it can be shared with the
Hugging Face Space and downloaded by the Render API without adding hundreds of
megabytes to ordinary Git history.

The current local checkpoint is an MLP baseline. The application labels its
validation accuracy and warns users that its predictions are experimental.

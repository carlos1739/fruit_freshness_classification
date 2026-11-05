from __future__ import annotations

import os
from pathlib import Path

from huggingface_hub import hf_hub_download


ROOT = Path(__file__).resolve().parent.parent
REPO_ID = os.environ.get(
    "MODEL_REPO_ID",
    "Carlos-leo/klasifikasi-kesegaran-buah",
)
REPO_TYPE = os.environ.get("MODEL_REPO_TYPE", "space")
TOKEN = os.environ.get("HF_TOKEN")
FILES = (
    "models/model_terbaik.keras",
    "models/model_terbaik_info.json",
)


def main() -> None:
    (ROOT / "models").mkdir(parents=True, exist_ok=True)
    for filename in FILES:
        downloaded = Path(
            hf_hub_download(
                repo_id=REPO_ID,
                filename=filename,
                repo_type=REPO_TYPE,
                token=TOKEN,
                local_dir=ROOT,
            )
        )
        destination = ROOT / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        print(f"Downloaded {filename} from {REPO_TYPE}/{REPO_ID}")


if __name__ == "__main__":
    main()

---
title: Klasifikasi Kesegaran Buah
emoji: 🍎
colorFrom: red
colorTo: yellow
sdk: static
pinned: false
---

# Klasifikasi Kesegaran Buah

Repositori ini berisi kode, data, model, dan hasil proyek klasifikasi kesegaran berbagai jenis buah. Kode proyek dikerjakan di [`notebooks/proyek1.ipynb`](notebooks/proyek1.ipynb).

## Anggota dan pembagian tugas

| Anggota | Tugas |
|---|---|
| Carlos Leonardo J. Dongoran | Persiapan notebook dan EDA: memuat dataset, menghitung jumlah gambar per kelas, memeriksa resolusi/format, dan menampilkan contoh gambar (bagian 1-5) |
| Percaya Mendrova | Praproses data: memeriksa gambar rusak, mendeteksi duplikat, memeriksa ketimpangan kelas, membagi data train/val/test, memeriksa kebocoran, dan menyimpan hasil (bagian 6-12) |
| Matthew Rivandi | Membuat input pipeline `tf.data`, memeriksa hasil pemuatan/batch, dan menyiapkan demo tensor (bagian 13) |
| Joni Fernando | Membuat baseline DNN dan model CNN, melatih keduanya dengan data train/validasi, lalu menyimpan model ke `models/` |
| Yohanes Cornelius Willfredi Simanjuntak | Mengevaluasi dan membandingkan DNN/CNN pada data test menggunakan accuracy, precision, recall, F1-score, dan confusion matrix; membuat visualisasi serta ringkasan hasil (belum di kerjakan) |

Joni mulai setelah input pipeline siap; Yohanes mengevaluasi model yang sudah dilatih tanpa memakai data test untuk memilih model. Rincian ada di [`docs/pembagian_tugas.md`](docs/pembagian_tugas.md).

## Struktur proyek

```text
README.md
requirements.txt
.gitignore
render.yaml
.github/workflows/deploy-huggingface-space.yml
frontend/                 # Flutter Web: upload gambar dan tampilan prediksi
backend/                  # FastAPI lama dan preprocessing TensorFlow
backend-node/             # API Node.js untuk model TensorFlow.js
models/                   # checkpoint Keras dan metadata kelas (Git LFS)
notebooks/
  proyek1.ipynb           # EDA, preprocessing, training, dan evaluasi
data/
  README.md
  raw/
  processed/
results/                  # Grafik dan tabel eksperimen
laporan/                  # Laporan proyek
video/                    # Informasi video demo
docs/
  pembagian_tugas.md
```

## Cara menjalankan

Pastikan Python 3.10 atau lebih baru, Git, dan Git LFS sudah terpasang. Clone repositori, lalu unduh file dataset yang dilacak Git LFS:

```powershell
git lfs install
git clone https://github.com/carlos1739/fruit_freshness_classification.git
cd NAMA-REPOSITORY
git lfs pull
```

Setiap anggota membuat virtual environment sendiri (`.venv` tidak disertakan di GitHub) dan menginstal pustaka dari `requirements.txt`:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

Di VS Code, pilih interpreter Python dari folder `.venv`, lalu buka notebook berikut untuk menjalankan proyek:

```powershell
jupyter notebook notebooks/proyek1.ipynb
```

Jika kebijakan PowerShell menghalangi aktivasi virtual environment, instal paket dan jalankan Jupyter tanpa aktivasi:

```powershell
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m jupyter notebook notebooks/proyek1.ipynb
```

Arsip `Fruits Dataset.zip` perlu tersedia di `data/raw/`. Jalankan sel notebook dari atas ke bawah untuk memeriksa distribusi kelas dan melihat contoh gambar. Simpan visualisasi ke `results/figures/`, hasil olahan ke `data/processed/`, dan model terlatih ke `models/`.

## Aplikasi web

Aplikasi memakai Flutter Web untuk antarmuka dan menyediakan API Node.js yang kompatibel dengan frontend. Hugging Face Static Space hanya menyajikan frontend; API Node.js tetap harus dijalankan pada layanan yang mendukung server Node.js.

Checkpoint yang saat ini tersimpan adalah **MLP baseline**, dengan akurasi validasi 58,95%. Prediksi merupakan demonstrasi eksperimental dan dapat keliru; jangan menganggapnya sebagai pemeriksaan kualitas pangan yang pasti. Perbarui `models/model_terbaik.keras` dan metadata setelah model final proyek disepakati.

### Jalankan backend Python lama secara lokal

Unduh checkpoint Git LFS, install dependensi, lalu jalankan API:

```powershell
git lfs install
git lfs pull --include="models/model_terbaik.keras"
python -m pip install -r backend/requirements.txt
python -m uvicorn backend.main:app --host 127.0.0.1 --port 7860
```

Health check API ada di `http://127.0.0.1:7860/api/health`; endpoint prediksi ada di `/api/predict`.

Untuk mengembangkan Flutter, jalankan backend di port `7860`, kemudian di terminal lain:

```powershell
cd frontend
flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://127.0.0.1:7860
```

### Jalankan backend Node.js

Node.js memerlukan checkpoint yang sudah dikonversi ke TensorFlow.js. Ikuti
instruksi di [`backend-node/README.md`](backend-node/README.md), lalu jalankan:

```powershell
cd backend-node
npm install
npm start
```

Konversi model bukan pekerjaan yang dapat dilakukan di VPS saat ini karena CPU
VPS tidak menyediakan AVX/AVX2 untuk TensorFlow. Setelah `models/model_tfjs/`
tersedia, frontend dapat diarahkan ke API Node.js dengan
`--dart-define=API_BASE_URL=https://URL-API-ANDA`.

### Hosting: Hugging Face Static + Node.js

1. Space `Carlos-leo/klasifikasi-kesegaran-buah` harus **Public** dan memakai SDK **Static**. GitHub Actions membangun Flutter dan mengirim hasil web beserta checkpoint ke Space.
2. Buat repository GitHub secret `HF_TOKEN` (izin write ke Space) dan `HF_SPACE_ID` dengan nilai `Carlos-leo/klasifikasi-kesegaran-buah`.
3. Hubungkan repository ini ke layanan Node.js yang dipilih. Contoh konfigurasi Render ada di [`render-node.yaml`](render-node.yaml), tetapi layanan gratis tetap dapat meminta metode pembayaran dan memiliki batas RAM/sleep.
4. Pastikan hasil konversi `models/model_tfjs/` ikut tersedia pada layanan API. Folder ini diabaikan Git karena ukurannya besar; unggah ke storage/model registry yang dipakai layanan, lalu set `TFJS_MODEL_DIR`.
5. Setelah API memberi URL HTTPS, build frontend dengan `--dart-define=API_BASE_URL=https://URL-API-ANDA`, lalu jalankan workflow **Deploy Flutter Web to Hugging Face Static Space**.
6. Buka `https://carlos-leo-klasifikasi-kesegaran-buah.hf.space`.

Hugging Face Static Space tidak menjalankan Node.js, jadi frontend dan API tetap
merupakan dua proses. Tidak ada opsi hosting gratis yang dapat menjalankan server
Node.js dan model sekitar 463 MB tanpa batas RAM atau kebijakan layanan.

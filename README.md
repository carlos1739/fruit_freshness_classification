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
backend/                  # FastAPI dan preprocessing TensorFlow
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

Aplikasi memakai Flutter Web untuk antarmuka, FastAPI/TensorFlow di Render untuk prediksi, serta Hugging Face Static Space untuk URL frontend publik. Semua source code tetap tersimpan dalam satu repository GitHub.

Checkpoint yang saat ini tersimpan adalah **MLP baseline**, dengan akurasi validasi 58,95%. Prediksi merupakan demonstrasi eksperimental dan dapat keliru; jangan menganggapnya sebagai pemeriksaan kualitas pangan yang pasti. Perbarui `models/model_terbaik.keras` dan metadata setelah model final proyek disepakati.

### Jalankan backend lokal

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

### Hosting gratis: Hugging Face Static + Render

1. Space `Carlos-leo/klasifikasi-kesegaran-buah` harus **Public** dan memakai SDK **Static**. GitHub Actions membangun Flutter dan mengirim hasil web beserta checkpoint ke Space.
2. Buat repository GitHub secret `HF_TOKEN` (izin write ke Space) dan `HF_SPACE_ID` dengan nilai `Carlos-leo/klasifikasi-kesegaran-buah`.
3. Hubungkan repository ini ke Render melalui **New → Blueprint**; Render akan membaca `render.yaml` dan membuat API free web service.
4. Commit dan push aplikasi serta `models/model_terbaik.keras` via Git LFS ke branch `main`; jalankan workflow **Deploy Flutter Web to Hugging Face Static Space**. Langkah pertama ini mempublikasikan frontend dan checkpoint ke Space; prediksi baru aktif setelah backend tersedia.
5. Hubungkan repository ini ke Render melalui **New → Blueprint**; Render akan membaca `render.yaml`, mengunduh checkpoint dari Space publik, lalu membuat API free web service.
6. Setelah Render memberi URL HTTPS, simpan URL itu sebagai GitHub Actions **variable** `RENDER_API_URL` (bukan secret) dan jalankan ulang workflow **Deploy Flutter Web to Hugging Face Static Space**.
7. Setelah workflow dan Render deploy sukses, buka `https://carlos-leo-klasifikasi-kesegaran-buah.hf.space`.

Render Free membatasi service ke 512 MB RAM dan menidurkan service saat tidak dipakai selama 15 menit. Checkpoint model berukuran sekitar 463 MB, sehingga API bisa gagal start atau perlu waktu untuk aktif kembali. Jika terjadi kehabisan memori, backend perlu compute ber-RAM lebih besar; Static Space sendiri tidak dapat menjalankan Python/TensorFlow.

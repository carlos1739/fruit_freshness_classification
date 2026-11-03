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
notebooks/proyek1.ipynb
data/
  README.md
  raw/
  processed/
models/
results/figures/
laporan/
video/README.md
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

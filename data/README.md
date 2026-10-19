# Dataset

Arsip dataset proyek `Fruits Dataset.zip` disimpan di `data/raw/`. Notebook mengekstrak gambar ke `data/processed/Fruits Dataset/` sebelum memeriksanya. Arsip berisi sekitar 2,9 GB data setelah diekstrak, jadi pastikan ruang penyimpanan mencukupi. File di dalam `raw/` dan `processed/` tidak dilacak Git agar dataset dan hasil olahan berukuran besar tidak ikut di-commit.

## Struktur dataset

Arsip berisi folder `Original Image/` dengan 16 kelas: `FreshApple`, `FreshBanana`, `FreshGrape`, `FreshGuava`, `FreshJujube`, `FreshOrange`, `FreshPomegranate`, `FreshStrawberry`, dan pasangan kelas `Rotten` untuk masing-masing jenis buah. Setiap kelas berisi 200 gambar (3.200 gambar total). Dataset ini tidak menyediakan folder train/test.

- **Sumber / URL:** https://data.mendeley.com/datasets/bdd69gyhv8/1

Data yang sudah dibersihkan atau dibagi menjadi train/test dapat disimpan di `data/processed/`; 
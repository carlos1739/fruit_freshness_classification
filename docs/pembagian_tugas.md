# Pembagian Tugas

Pembagian tugas ini mengikuti alur pengerjaan di notebook. Setiap bagian
disiapkan agar dapat dilanjutkan oleh anggota berikutnya: data diperiksa dan
dibersihkan terlebih dahulu, kemudian pipeline dibuat, model dilatih, dan
hasilnya dievaluasi pada tahap akhir.

| Anggota | Tugas |
|---|---|
| Carlos Leonardo J. Dongoran | Menyiapkan notebook dan melakukan eksplorasi awal dataset pada [`notebooks/proyek1.ipynb`](../notebooks/proyek1.ipynb). Pekerjaannya meliputi memuat data, melihat jumlah gambar di setiap kelas, memeriksa resolusi dan format file, serta menampilkan contoh gambar untuk memastikan isi dataset sesuai (bagian 1–5). |
| Percaya Mendrova | Menyiapkan data sebelum masuk ke model. Ia memeriksa gambar yang rusak, mencari duplikat, melihat keseimbangan kelas, membuat pembagian train/validation/test, memastikan tidak terjadi kebocoran data antar-split, lalu menyimpan hasil praproses (bagian 6–12). |
| Matthew Rivandi | Membuat input pipeline `tf.data` dari hasil praproses. Ia memastikan gambar dapat dibaca dalam batch, ukuran dan tipe datanya sesuai, augmentasi hanya diterapkan pada data train, serta menyiapkan contoh pemeriksaan tensor (bagian 13). |
| Joni Fernando | Mengembangkan dan melatih beberapa model klasifikasi, mulai dari baseline DNN/MLP, CNN, hingga model dengan regularisasi dan transfer learning. Setiap model dibandingkan menggunakan data train dan validation, kemudian model terbaik beserta informasinya disimpan di `models/` (bagian 14). |
| Yohanes Cornelius Willfredi Simanjuntak | Mengevaluasi model terbaik menggunakan data test yang belum dipakai saat pemilihan model. Ia menghitung accuracy, precision, recall, dan F1-score, membuat confusion matrix, lalu merangkum hasil serta kesalahan klasifikasi yang ditemukan (bagian 15). |

## Koordinasi

- **Ketua/koordinator:** Carlos Leonardo J. Dongoran
- **Urutan kerja:** EDA → praproses → input pipeline → pelatihan model → evaluasi akhir.
- **Catatan evaluasi:** data test hanya digunakan setelah model terbaik dipilih,
  sehingga tidak ikut memengaruhi proses pemilihan model.
```
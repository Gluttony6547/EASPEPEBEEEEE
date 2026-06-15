# Pembaruan Versi `b3f5243`

Commit: `b3f5243`  
Judul: `Fix sugar log layout and portrait orientation`

## Screenshots

<img width="369" height="821" alt="image" src="https://github.com/user-attachments/assets/8d0c470e-9c1f-477c-8032-67761248e628" />
<img width="371" height="823" alt="image" src="https://github.com/user-attachments/assets/e42117b1-02e2-4ca0-9ff7-6861ed04c4d5" />
<img width="339" height="744" alt="image" src="https://github.com/user-attachments/assets/9a6dd7d0-1c7a-4947-8782-be120df7ad8e" />
<img width="371" height="835" alt="image" src="https://github.com/user-attachments/assets/7ee77f58-3b4b-4d4d-89b7-ed01b642fe6f" />

## Ringkasan

Versi ini berfokus pada perapihan pengalaman layar `Log Gula`, terutama untuk tata letak aksi cepat dan konsistensi orientasi aplikasi di Android.

## Perubahan Kode

### 1. Kunci orientasi portrait

Perubahan dilakukan di:

- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`

Detail:

- Activity Android sekarang dipaksa ke `portrait` lewat manifest.
- Saat aplikasi dijalankan di platform non-web, Flutter juga memanggil `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])`.

Dampak:

- Tampilan tidak lagi berpindah ke landscape.
- Layout `Log Gula` menjadi lebih stabil di perangkat Android.

### 2. Perapihan aksi cepat di layar Log Gula

Perubahan utama dilakukan di:

- `lib/screens/sugar_log_screen.dart`

Detail:

- Tombol aksi `Barcode`, `Olahraga`, dan `Manual` dipindahkan dari `floatingActionButton` bertumpuk menjadi panel aksi cepat di dalam konten halaman.
- Ditambahkan widget `_LogQuickActions` berbasis `LayoutBuilder` dan `Wrap` agar susunan tombol adaptif pada lebar layar kecil.
- Tombol `Manual` dibedakan secara visual dengan `OutlinedButton`, sementara aksi utama lain tetap menggunakan `FilledButton`.

Dampak:

- Aksi utama lebih mudah dijangkau.
- Risiko tombol bertumpuk atau terpotong di layar sempit berkurang.
- Struktur halaman `Log Gula` menjadi lebih rapi dan lebih konsisten dengan isi halaman.

### 3. Penyesuaian spacing halaman

Perubahan dilakukan di:

- `lib/theme/gula_theme.dart`

Detail:

- `bottomPadding` default pada `GulaPage` diubah dari `116` menjadi `104`.
- `SafeArea` pada bagian bawah di-nonaktifkan dengan `bottom: false`.

Dampak:

- Komposisi halaman lebih rapat dan proporsional.
- Ruang kosong di bagian bawah berkurang.
- Layout lebih cocok dengan panel aksi cepat baru di layar `Log Gula`.

### 4. Penyesuaian desain dan font yang lebih kekinian

Perubahan utama terkait visual dilakukan di:

- `pubspec.yaml`
- `assets/fonts/`
- `lib/theme/gula_theme.dart`

Detail font baru yang digunakan sekarang:

- Keluarga font utama: `Roboto`
- Keluarga font heading/display: `RobotoSlab`

Lokasi asset font:

- `assets/fonts/Roboto-Regular.ttf`
- `assets/fonts/Roboto-Medium.ttf`
- `assets/fonts/Roboto-Bold.ttf`
- `assets/fonts/Roboto-Black.ttf`
- `assets/fonts/RobotoSlab-VariableFont_wght.ttf`

Lokasi pemanggilan font:

- `pubspec.yaml`
  Mendaftarkan family `Roboto` dan `RobotoSlab` ke Flutter asset system.
- `lib/theme/gula_theme.dart`
  `ThemeData.fontFamily` diatur ke `Roboto` sebagai font dasar aplikasi.
- `lib/theme/gula_theme.dart`
  Beberapa elemen judul seperti `headlineLarge`, `headlineMedium`, `headlineSmall`, `AppBar`, dan elemen merek menggunakan `RobotoSlab`.

Penyesuaian desain minimalis yang digunakan sekarang:

- Palet warna dibuat lebih tenang dan konsisten melalui `GulaColors`, dengan dominasi hijau lembut, krem, dan aksen amber/coral.
- Permukaan UI memakai `Card`, `GulaSurface`, border tipis, dan radius yang konsisten agar tampilan terasa bersih.
- Layout mengurangi elemen yang bertumpuk dan memindahkan aksi penting ke komponen yang lebih terstruktur.
- Tipografi dibedakan jelas antara teks isi dan heading, sehingga tampilan terasa lebih modern dan lebih mudah dipindai.

Dampak:

- Tampilan aplikasi terasa lebih ringan, rapi, dan lebih modern.
- Hirarki visual lebih jelas, terutama di layar `Log Gula`, `Beranda`, dan komponen branded aplikasi.

### 5. Penambahan fitur tracking kalori dan olahraga

Perubahan utama terkait fitur ini dilakukan di:

- `lib/domain/activity_logic.dart`
- `lib/screens/activity_log_sheet.dart`
- `lib/screens/sugar_log_screen.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/challenge_screen.dart`
- `lib/services/challenge_service.dart`

Fitur yang tersedia sekarang:

- Pengguna dapat mencatat aktivitas olahraga dari alur `Log Gula`.
- Aktivitas mendukung mode `Jalan kaki` dan `Lari`.
- Sistem menyimpan jarak tempuh, menghitung estimasi kalori terbakar, dan memakai data itu untuk progress challenge olahraga.
- Dashboard `Beranda` menampilkan ringkasan kalori terbakar dan progres target olahraga mingguan.

Perhitungan kalori yang dipakai:

Perhitungan ada di `lib/domain/activity_logic.dart` melalui fungsi `estimateCaloriesBurned(...)`.

Rumus:

`kalori = MET x berat_badan_kg x durasi_jam`

Komponen rumus:

- `MET` ditentukan dari jenis aktivitas:
  - jalan kaki = `3.5`
  - lari = `8.5`
- durasi dihitung dari:
  - `durasi_jam = jarak_km / kecepatan_asumsi_km_per_jam`
- kecepatan asumsi:
  - jalan kaki = `5.0 km/jam`
  - lari = `8.0 km/jam`

Artinya, estimasi kalori tidak hanya bergantung pada jarak, tetapi juga mode olahraga dan berat badan pengguna.

Eksternal API yang digunakan terkait fitur ini:

- `Open Food Facts`
  Dipakai sebagai fallback untuk lookup nutrisi/barcode makanan.
- Firebase Cloud Functions `lookupNutritionByBarcode`
  Dipanggil oleh `NutritionLookupService` untuk mengambil data nutrisi barcode dari backend.

Provider eksternal yang dipakai di backend `functions/` untuk lookup nutrisi:

- `c0r.ai`
- `CalorieAPI`
- `USDA FoodData Central`
- `Edamam`
- `Open Food Facts`

Catatan:

- API eksternal di atas dipakai untuk fitur nutrisi dan log gula berbasis barcode.
- Tracking olahraga dan perhitungan kalori dilakukan lokal di aplikasi dari data profil dan input aktivitas pengguna, bukan dari API pihak ketiga.

## Hasil Pengujian

Pengujian yang dijalankan pada direktori `C:\SMT 6\PPB\EAS`:

- `flutter test` -> lulus
- `flutter analyze` -> lulus, tanpa issue
- `npm test` pada `functions/` -> lulus

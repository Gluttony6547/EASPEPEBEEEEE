# Kontrak Tim — Sugar Pals
> Dokumen ini adalah kesepakatan bersama tim Sugar Pals yang wajib dipatuhi selama development berlangsung.
> Ditandatangani dan disepakati sebelum development dimulai.

---

## Anggota & Tanggung Jawab

| Nama | Branch | Fitur | Folder |
|------|--------|-------|--------|
| [Nama Anggota 1] | `feature/risk-assessment` | Kalkulator Risiko Diabetes | `lib/screens/assessment/` |
| [Nama Anggota 2] | `feature/sugar-log` | Log Konsumsi Gula Harian | `lib/screens/sugar_log/` |
| [Nama Anggota 3] | `feature/challenge-streak` | Tantangan & Streak | `lib/screens/challenge/` |

---

## Bagian 1 — Kontrak Kerja

### 1.1 Komitmen individu

- Setiap anggota **wajib commit minimal sekali per hari** di hari aktif development.
- Setiap anggota bertanggung jawab penuh atas fitur di folder masing-masing — dari UI sampai koneksi Firestore.
- Kalau ada kendala teknis, **wajib lapor ke grup maksimal 1 jam** setelah menemukan masalah — jangan diam sampai deadline.
- Setiap anggota wajib hadir saat sesi integrasi (Hari 12) tanpa pengecualian.

### 1.2 Pembagian file — ownership

Setiap anggota hanya boleh mengedit file di dalam folder miliknya sendiri tanpa perlu koordinasi:

```
Anggota 1 → lib/screens/assessment/
Anggota 2 → lib/screens/sugar_log/
Anggota 3 → lib/screens/challenge/
```

### 1.3 File shared — wajib koordinasi sebelum edit

File berikut adalah milik bersama. **Dilarang mengedit tanpa izin tim:**

```
lib/main.dart
lib/navigation_shell.dart
lib/app_constants.dart
lib/services/notification_service.dart
lib/services/open_food_facts_service.dart
lib/domain/health_logic.dart
pubspec.yaml
android/app/build.gradle.kts
firestore.rules
```

Format koordinasi di grup sebelum edit file shared:

```
🔒 Mau edit: [nama file]
Alasan: [kenapa perlu diedit]
Estimasi selesai: [berapa menit]
```

Tunggu minimal satu anggota lain reply **"ok"** sebelum mulai edit.

### 1.4 Jadwal dan milestone

| Hari | Target |
|------|--------|
| 1–2 | Setup selesai, semua anggota bisa `flutter run` |
| 3–6 | Create + Read masing-masing fitur jalan |
| 7 | **Milestone 1**: semua fitur bisa input dan tampilkan data dari Firestore |
| 8–10 | Update + Delete + Push Notification |
| 11 | Polish UI masing-masing fitur |
| 12 | **Integrasi bersama** — merge, bug fixing |
| 13 | Latihan demo, siapkan slide |
| 14 | **Demo ke dosen** |

---

## Bagian 2 — Aturan Git

### 2.1 Setup awal (wajib dilakukan sekali sebelum mulai)

Setiap anggota wajib set identity git sesuai akun GitHub masing-masing:

```bash
git config --global user.name "Nama Sesuai GitHub"
git config --global user.email "email@sesuai.github.com"
```

Verifikasi:

```bash
git config user.name
git config user.email
```

> Kalau identity salah, commit tidak akan tercatat sebagai kontribusi di GitHub.

### 2.2 Rutinitas harian — wajib dijalankan berurutan

**Sebelum mulai coding setiap hari:**

```bash
git checkout feature/[branch-kalian]
git pull origin main
```

**Setelah selesai coding:**

```bash
git add .
git commit -m "[type]([scope]): [deskripsi singkat]"
git push origin feature/[branch-kalian]
```

### 2.3 Format pesan commit — wajib dipatuhi

Format:
```
[type]([scope]): [deskripsi singkat dalam bahasa Indonesia]
```

| Type | Kapan dipakai |
|------|--------------|
| `feat` | Menambahkan fitur baru |
| `fix` | Memperbaiki bug |
| `refactor` | Mengubah struktur kode tanpa mengubah fungsionalitas |
| `style` | Perubahan UI/styling |
| `docs` | Update dokumentasi |
| `chore` | Hal-hal non-fungsional (update package, config, dll) |

Scope disesuaikan dengan nama fitur:

| Anggota | Scope |
|---------|-------|
| Anggota 1 | `risk` |
| Anggota 2 | `sugar-log` |
| Anggota 3 | `challenge` |
| Semua | `main`, `shared`, `notif` |

**Contoh commit yang benar:**

```bash
feat(risk): tambah form kuesioner gaya hidup
feat(sugar-log): integrasi Open Food Facts API
feat(challenge): implementasi validasi streak otomatis
fix(risk): fix kalkulasi skor saat field kosong
fix(sugar-log): fix total gula tidak terupdate setelah hapus log
style(challenge): update warna progress bar badge
refactor(risk): pisah logika kalkulasi ke health_logic.dart
chore: update firebase_messaging ke versi terbaru
```

**Contoh commit yang dilarang:**

```bash
git commit -m "update"          # ← tidak jelas
git commit -m "fix bug"         # ← bug apa?
git commit -m "done"            # ← done apa?
git commit -m "asdfgh"          # ← tidak ada artinya
git commit -m "wip"             # ← jangan push WIP ke branch
```

### 2.4 Alur merge ke main

Hanya ketua yang boleh merge ke `main`. Alurnya:

```
coding di branch sendiri
    ↓
push ke branch feature
    ↓
buat Pull Request di GitHub
    ↓
ketua review + merge ke main
    ↓
semua anggota pull main ke branch masing-masing
```

Setelah ketua merge:

```bash
# Semua anggota jalankan ini
git checkout feature/[branch-kalian]
git pull origin main
```

### 2.5 Larangan keras

- ❌ **Jangan push langsung ke `main`**
- ❌ **Jangan force push** (`git push --force`)
- ❌ **Jangan commit `google-services.json`** — sudah ada di `.gitignore`
- ❌ **Jangan commit `firebase_options.dart`** jika berisi data sensitif
- ❌ **Jangan edit folder anggota lain** tanpa izin

---

## Bagian 3 — Kesepakatan Penulisan Kode

### 3.1 Bahasa

- **Kode (nama variabel, fungsi, class)** → Bahasa Inggris
- **Komentar & string UI** → Bahasa Indonesia
- **Pesan commit** → Bahasa Indonesia

```dart
// ✅ Benar
final sugarLogList = <SugarLog>[];          // variabel: Inggris
Text('Log Gula Harian'),                    // UI: Indonesia

// ❌ Salah
final daftarLogGula = <SugarLog>[];
Text('Daily Sugar Log'),
```

### 3.2 Penamaan

```dart
// Class → PascalCase
class SugarLogScreen {}
class ChallengeModel {}

// Variabel & fungsi → camelCase
double totalSugarGram = 0.0;
Future<void> fetchSugarLogs() async {}

// Konstanta → camelCase dengan prefix k (opsional)
const double defaultTarget = 50.0;

// File → snake_case
sugar_log_screen.dart
challenge_model.dart
open_food_facts_service.dart
```

### 3.3 Struktur widget

Pisahkan widget besar menjadi method atau class kecil:

```dart
// ✅ Benar — dipecah jadi method
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: _buildAppBar(),
    body: _buildBody(),
  );
}

Widget _buildAppBar() { ... }
Widget _buildBody() { ... }

// ❌ Salah — semua dalam satu build
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('...'),
      // 50 baris kode di sini
    ),
    body: Column(
      // 100 baris kode di sini
    ),
  );
}
```

### 3.4 Firestore — wajib pakai konstanta dari `app_constants.dart`

```dart
// ✅ Benar
FirebaseFirestore.instance.collection('users')

// Tambahkan konstanta koleksi di app_constants.dart
// dan pakai di seluruh kode
class FSCollection {
  static const users = 'users';
  static const challenges = 'challenges';
}
```

> Jangan menulis nama koleksi/field Firestore sebagai string literal langsung — typo tidak akan ketahuan sampai runtime.

### 3.5 Error handling — wajib ada di semua operasi async

```dart
// ✅ Benar
Future<void> saveSugarLog(SugarLog log) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sugarLogs')
        .add(log.toMap());
  } catch (e) {
    // Tampilkan pesan error ke user, jangan diam
    debugPrint('Error saving sugar log: $e');
  }
}

// ❌ Salah — tidak ada error handling
Future<void> saveSugarLog(SugarLog log) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sugarLogs')
      .add(log.toMap());
}
```

### 3.6 Jangan hardcode nilai penting

```dart
// ✅ Benar — ambil dari AppConstants
final target = AppConstants.defaultSugarTargetGram;

// ❌ Salah — hardcode langsung
final target = 50.0;
```

### 3.7 Komentar — tulis yang bermakna

```dart
// ✅ Benar — menjelaskan KENAPA, bukan APA
// Validasi streak dijalankan setiap kali log baru ditambahkan,
// bukan saat user tap tombol, supaya tidak bisa dicurangi
await _validateStreak(uid);

// ❌ Salah — menjelaskan hal yang sudah jelas dari kode
// Validasi streak
await _validateStreak(uid);
```

---

## Tanda Tangan Kesepakatan

Dengan bergabung di repository ini dan melakukan commit pertama, setiap anggota dianggap telah membaca dan menyetujui seluruh isi dokumen ini.

| Nama | Branch | Tanggal |
|------|--------|---------|
| [Nama Anggota 1] | `feature/risk-assessment` | |
| [Nama Anggota 2] | `feature/sugar-log` | |
| [Nama Anggota 3] | `feature/challenge-streak` | |

---

*Sugar Pals — Final Project Mobile Programming*
*SDG 3.4 — Good Health & Well-Being*

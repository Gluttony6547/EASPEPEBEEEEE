import 'package:intl/intl.dart';

class RiskResult {
  const RiskResult({
    required this.bmi,
    required this.score,
    required this.level,
    required this.recommendation,
  });

  final double bmi;
  final int score;
  final String level;
  final String recommendation;
}

RiskResult calculateRisk({
  required int age,
  required double heightCm,
  required double weightKg,
  required int sugaryDrinksPerDay,
  required String drinkIntensity,
  required int activityMinutesPerWeek,
  required bool familyHistory,
}) {
  final heightM = heightCm / 100;
  final bmi = heightM <= 0 ? 0.0 : weightKg / (heightM * heightM);
  var score = 0;

  // BMI
  if (bmi >= 30) {
    score += 30;
  } else if (bmi >= 25) {
    score += 20;
  } else if (bmi >= 23) {
    score += 8;
  }

  // Usia
  if (age >= 45) {
    score += 25;
  } else if (age >= 35) {
    score += 15;
  } else if (age >= 25) {
    score += 5;
  }

  // Minuman manis: frekuensi × intensitas × 5
  final intensityMultiplier = switch (drinkIntensity) {
    'berat' => 3,
    'sedang' => 2,
    _ => 1,
  };
  score += sugaryDrinksPerDay * intensityMultiplier * 5;

  // Aktivitas fisik
  if (activityMinutesPerWeek < 60) {
    score += 25;
  } else if (activityMinutesPerWeek < 150) {
    score += 12;
  }

  // Riwayat keluarga
  if (familyHistory) score += 20;

  // Level risiko
  final String level;
  final String recommendation;

  if (score >= 70) {
    level = 'Sangat Tinggi';
    recommendation =
    'Segera konsultasi ke dokter dan lakukan skrining HbA1c. '
        'Kurangi drastis minuman manis dan tingkatkan aktivitas fisik.';
  } else if (score >= 45) {
    level = 'Tinggi';
    recommendation =
    'Batasi minuman manis maksimal 1x sehari, '
        'mulai olahraga teratur, dan cek gula darah setahun sekali.';
  } else if (score >= 25) {
    level = 'Sedang';
    recommendation =
    'Pantau konsumsi gula harian, biasakan olahraga ringan '
        '3x seminggu, dan perbanyak serat dari sayur dan buah.';
  } else if (score >= 10) {
    level = 'Rendah';
    recommendation =
    'Pertahankan pola makan seimbang, batasi minuman manis, '
        'dan tetap aktif bergerak minimal 150 menit per minggu.';
  } else {
    level = 'Sangat Rendah';
    recommendation =
    'Pertahankan gaya hidup sehat dan tetap rutin cek '
        'kesehatan tahunan.';
  }

  return RiskResult(
    bmi: double.parse(bmi.toStringAsFixed(1)),
    score: score,
    level: level,
    recommendation: recommendation,
  );
}

String dayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime parseDayKey(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.creditedDates,
    required this.failedDates,
    required this.progressDays,
    required this.isCompleted,
  });

  final List<String> creditedDates;
  final List<String> failedDates;
  final int progressDays;
  final bool isCompleted;
}

ChallengeProgress recalculateChallengeProgress({
  required DateTime startDate,
  required int durationDays,
  required double dailyTargetGram,
  required Map<String, double> totalsByDay,
  required Set<String> daysWithLogs,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final start = dateOnly(startDate);
  final credited = <String>[];
  final failed = <String>[];

  for (var offset = 0; offset < durationDays; offset++) {
    final day = start.add(Duration(days: offset));
    if (day.isAfter(today)) break;
    final key = dayKey(day);
    if (!daysWithLogs.contains(key)) continue;
    final total = totalsByDay[key] ?? 0;
    if (total <= dailyTargetGram) {
      credited.add(key);
    } else {
      failed.add(key);
    }
  }

  return ChallengeProgress(
    creditedDates: credited,
    failedDates: failed,
    progressDays: credited.length,
    isCompleted: credited.length >= durationDays,
  );
}

double totalSugarForDay(
  Iterable<Map<String, Object?>> logs,
  String selectedDayKey,
) {
  return logs.fold<double>(0, (sum, log) {
    if (log['dayKey'] != selectedDayKey) return sum;
    final value = log['sugarGram'];
    if (value is num) return sum + value.toDouble();
    return sum;
  });
}

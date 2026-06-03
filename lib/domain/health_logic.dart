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
  required int activityMinutesPerWeek,
  required bool familyHistory,
}) {
  final heightM = heightCm / 100;
  final bmi = heightM <= 0 ? 0.0 : weightKg / (heightM * heightM);
  var score = 0;

  if (age >= 35) score += 2;
  if (bmi >= 30) {
    score += 3;
  } else if (bmi >= 25) {
    score += 2;
  }
  if (sugaryDrinksPerDay >= 3) {
    score += 3;
  } else if (sugaryDrinksPerDay >= 1) {
    score += 1;
  }
  if (activityMinutesPerWeek < 150) score += 2;
  if (familyHistory) score += 3;

  if (score >= 8) {
    return RiskResult(
      bmi: bmi,
      score: score,
      level: 'Tinggi',
      recommendation:
          'Kurangi minuman manis, tambah aktivitas fisik, dan konsultasi ke tenaga kesehatan.',
    );
  }
  if (score >= 4) {
    return RiskResult(
      bmi: bmi,
      score: score,
      level: 'Sedang',
      recommendation:
          'Mulai pantau konsumsi gula harian dan pertahankan aktivitas minimal 150 menit per minggu.',
    );
  }
  return RiskResult(
    bmi: bmi,
    score: score,
    level: 'Rendah',
    recommendation:
        'Pertahankan pola makan seimbang dan tetap cek kebiasaan minuman manis.',
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

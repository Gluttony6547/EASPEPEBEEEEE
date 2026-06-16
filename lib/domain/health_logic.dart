import 'package:intl/intl.dart';

const walkingMode = 'walk';
const runningMode = 'run';
const sugarChallengeType = 'sugar';
const activityChallengeType = 'activity';

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

  final intensityMultiplier = switch (drinkIntensity) {
    'berat' => 3,
    'sedang' => 2,
    _ => 1,
  };
  score += sugaryDrinksPerDay * intensityMultiplier * 5;

  if (activityMinutesPerWeek < 60) {
    score += 25;
  } else if (activityMinutesPerWeek < 150) {
    score += 12;
  }

  if (familyHistory) score += 20;

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

DateTime weekStart(DateTime date) {
  final selected = dateOnly(date);
  return selected.subtract(Duration(days: selected.weekday - DateTime.monday));
}

DateTime weekEnd(DateTime date) => weekStart(date).add(const Duration(days: 6));

DateTime parseDayKey(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

double? parseLocalizedDouble(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;

  var normalized = text.replaceAll(RegExp(r'\s+'), '');
  if (normalized.contains(',') && normalized.contains('.')) {
    normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
  } else {
    normalized = normalized.replaceAll(',', '.');
  }
  return double.tryParse(normalized);
}

int? parseLocalizedInt(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  if (text.contains(',') || text.contains('.')) return null;
  return int.tryParse(text);
}

String normalizeChallengeType(Object? value) {
  final raw = value?.toString().toLowerCase().trim();
  return raw == activityChallengeType
      ? activityChallengeType
      : sugarChallengeType;
}

String normalizeActivityMode(Object? value) {
  final raw = value?.toString().toLowerCase().trim();
  return raw == runningMode ? runningMode : walkingMode;
}

String activityModeLabel(String mode) {
  return normalizeActivityMode(mode) == runningMode ? 'Lari' : 'Jalan kaki';
}

double activityMet(String mode) {
  return normalizeActivityMode(mode) == runningMode ? 8.5 : 3.5;
}

double assumedSpeedKmPerHour(String mode) {
  return normalizeActivityMode(mode) == runningMode ? 8.0 : 5.0;
}

double estimateCaloriesBurned({
  required double distanceKm,
  required double weightKg,
  required String activityMode,
}) {
  if (distanceKm <= 0 || weightKg <= 0) return 0;
  final durationHours = distanceKm / assumedSpeedKmPerHour(activityMode);
  return activityMet(activityMode) * weightKg * durationHours;
}

double totalActivityDistanceForDay({
  required Map<String, Map<String, double>> distanceByDayAndMode,
  required String dayKey,
  required String activityMode,
}) {
  return distanceByDayAndMode[dayKey]?[normalizeActivityMode(activityMode)] ??
      0;
}

class ChallengeProgress {
  const ChallengeProgress({
    required this.creditedDates,
    required this.failedDates,
    this.missedDates = const [],
    required this.progressDays,
    required this.isCompleted,
    this.isExpired = false,
  });

  final List<String> creditedDates;
  final List<String> failedDates;
  final List<String> missedDates;
  final int progressDays;
  final bool isCompleted;
  final bool isExpired;
}

ChallengeProgress recalculateChallengeProgress({
  required DateTime startDate,
  required int durationDays,
  required double dailyTargetGram,
  required Map<String, double> totalsByDay,
  required Set<String> daysWithLogs,
  String challengeType = sugarChallengeType,
  Map<String, Map<String, double>> distanceByDayAndMode = const {},
  Set<String> daysWithActivity = const {},
  double dailyDistanceTargetKm = 0,
  String activityMode = walkingMode,
  DateTime? now,
}) {
  final today = dateOnly(now ?? DateTime.now());
  final start = dateOnly(startDate);
  final credited = <String>[];
  final failed = <String>[];
  final missed = <String>[];
  final normalizedType = normalizeChallengeType(challengeType);
  final normalizedMode = normalizeActivityMode(activityMode);

  for (var offset = 0; offset < durationDays; offset++) {
    final day = start.add(Duration(days: offset));
    if (day.isAfter(today)) break;
    final key = dayKey(day);
    final isToday = day.isAtSameMomentAs(today);

    if (normalizedType == activityChallengeType) {
      final distance = totalActivityDistanceForDay(
        distanceByDayAndMode: distanceByDayAndMode,
        dayKey: key,
        activityMode: normalizedMode,
      );
      final hasActivity = daysWithActivity.contains(key) || distance > 0;
      final distanceOk =
          hasActivity &&
          (dailyDistanceTargetKm <= 0 || distance >= dailyDistanceTargetKm);

      if (distanceOk) {
        credited.add(key);
      } else if (!isToday) {
        failed.add(key);
        if (!hasActivity) missed.add(key);
      }
      continue;
    }

    final hasSugarLog = daysWithLogs.contains(key);
    final total = totalsByDay[key] ?? 0;
    if (hasSugarLog && total <= dailyTargetGram) {
      credited.add(key);
    } else if (!isToday || (hasSugarLog && total > dailyTargetGram)) {
      failed.add(key);
      if (!hasSugarLog) missed.add(key);
    }
  }

  final completed = credited.length >= durationDays;
  return ChallengeProgress(
    creditedDates: credited,
    failedDates: failed,
    missedDates: missed,
    progressDays: credited.length,
    isCompleted: completed,
    isExpired: !completed && failed.isNotEmpty,
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

double totalActivityDurationForWeek(
  Iterable<Map<String, Object?>> logs, {
  required DateTime weekDate,
}) {
  final start = weekStart(weekDate);
  final end = weekEnd(weekDate);
  return logs.fold<double>(0, (sum, log) {
    final key = log['dayKey']?.toString();
    if (key == null || key.isEmpty) return sum;

    DateTime logDate;
    try {
      logDate = parseDayKey(key);
    } on FormatException {
      return sum;
    } on RangeError {
      return sum;
    }

    if (logDate.isBefore(start) || logDate.isAfter(end)) return sum;
    final value = log['durationMinutes'];
    if (value is num) return sum + value.toDouble();
    return sum;
  });
}

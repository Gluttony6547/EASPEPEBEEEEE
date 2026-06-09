const defaultDailySugarTargetGram = 50.0;

String sugarLogDayKey(DateTime date) {
  final local = date.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

double? parseSugarNumber(String? value) {
  final normalized = value?.trim().replaceAll(',', '.');
  if (normalized == null || normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

double calculateSugarGram({
  required double sugars100g,
  required double portionGram,
}) {
  if (sugars100g < 0 || portionGram < 0) return 0;
  return (sugars100g * portionGram) / 100;
}

double totalSugarForDay(Iterable<Map<String, dynamic>> logs, String dayKey) {
  return logs.fold<double>(0, (total, log) {
    if (log['dayKey'] != dayKey) return total;
    final sugar = log['sugarGram'];
    if (sugar is num) return total + sugar.toDouble();
    return total;
  });
}

String formatSugarDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

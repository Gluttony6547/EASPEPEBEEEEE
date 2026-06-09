import 'package:flutter_test/flutter_test.dart';
import 'package:sugarpals/domain/sugar_log_logic.dart';

void main() {
  test('sugarLogDayKey formats local date', () {
    expect(sugarLogDayKey(DateTime(2026, 6, 9)), '2026-06-09');
  });

  test('parseSugarNumber accepts decimal comma', () {
    expect(parseSugarNumber('12,5'), 12.5);
  });

  test('calculateSugarGram scales from per 100g sugar', () {
    expect(calculateSugarGram(sugars100g: 8, portionGram: 250), 20);
  });

  test('totalSugarForDay only sums matching day', () {
    final logs = [
      {'dayKey': '2026-06-09', 'sugarGram': 10},
      {'dayKey': '2026-06-09', 'sugarGram': 3.5},
      {'dayKey': '2026-06-10', 'sugarGram': 99},
    ];

    expect(totalSugarForDay(logs, '2026-06-09'), 13.5);
  });
}

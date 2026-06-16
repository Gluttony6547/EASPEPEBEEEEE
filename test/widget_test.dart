import 'package:flutter_test/flutter_test.dart';
import 'package:sugarpals/app_constants.dart';
import 'package:sugarpals/domain/health_logic.dart';
import 'package:sugarpals/services/open_food_facts_service.dart';

void main() {
  test('default health targets are available', () {
    expect(AppConstants.defaultSugarTargetGram, 50);
    expect(AppConstants.defaultWeeklyExerciseTargetMinutes, 150);
  });

  test('localized decimal parser accepts comma and dot', () {
    expect(parseLocalizedDouble('1,5'), 1.5);
    expect(parseLocalizedDouble('1.5'), 1.5);
  });

  test('Open Food Facts parser reads root sugar fields', () {
    const body = '''
{
  "code": "3017620422003",
  "status": 1,
  "product": {
    "code": "3017620422003",
    "product_name": "Nutella",
    "brands": "Nutella, Yum yum",
    "serving_size_imported": "15 g (15)",
    "sugars_100g": 56.3
  }
}
''';

    final product = parseOpenFoodFactsProduct(body, '3017620422003');

    expect(product, isNotNull);
    expect(product!.name, 'Nutella');
    expect(product.sugarPer100g, 56.3);
    expect(product.sugarPerServing, closeTo(8.445, 0.001));
  });
}

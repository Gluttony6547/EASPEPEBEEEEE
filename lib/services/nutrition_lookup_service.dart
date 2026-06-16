import 'package:cloud_functions/cloud_functions.dart';

import 'open_food_facts_service.dart';

class NutritionProduct {
  const NutritionProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.serving,
    required this.sugarPer100g,
    required this.sugarPerServing,
    required this.source,
    required this.confidence,
    required this.needsReview,
    required this.providerCount,
    required this.cacheHit,
  });

  final String barcode;
  final String name;
  final String brand;
  final String serving;
  final double? sugarPer100g;
  final double? sugarPerServing;
  final String source;
  final double confidence;
  final bool needsReview;
  final int providerCount;
  final bool cacheHit;

  double? get suggestedSugarGram => sugarPerServing ?? sugarPer100g;

  String get sourceLabel => source
      .split('+')
      .map(
        (item) => switch (item) {
          'c0r' => 'c0r.ai',
          'calorie_api' => 'CalorieAPI',
          'usda_fdc' => 'USDA FDC',
          'edamam' => 'Edamam',
          'open_food_facts' => 'Open Food Facts',
          'open_food_facts_client' => 'Open Food Facts',
          _ => item,
        },
      )
      .join(' + ');

  factory NutritionProduct.fromCallableData(Object? data) {
    final map = _stringMap(data);
    return NutritionProduct(
      barcode: _stringOrDefault(map['barcode'], ''),
      name: _stringOrDefault(map['name'], 'Produk tanpa nama'),
      brand: _stringOrDefault(map['brand'], 'Brand tidak tersedia'),
      serving: _stringOrDefault(map['serving'], '1 porsi'),
      sugarPer100g: _doubleOrNull(map['sugarPer100g']),
      sugarPerServing: _doubleOrNull(map['sugarPerServing']),
      source: _stringOrDefault(map['source'], 'nutrition_proxy'),
      confidence: _doubleOrNull(map['confidence']) ?? 0.5,
      needsReview: map['needsReview'] == true,
      providerCount: (map['providerCount'] as num?)?.toInt() ?? 1,
      cacheHit: map['cacheHit'] == true,
    );
  }

  factory NutritionProduct.fromOpenFoodFactsFallback(FoodProduct product) {
    return NutritionProduct(
      barcode: product.barcode,
      name: product.name,
      brand: product.brand,
      serving: '1 porsi',
      sugarPer100g: product.sugarPer100g,
      sugarPerServing: product.sugarPerServing,
      source: 'open_food_facts_client',
      confidence: 0.62,
      needsReview: true,
      providerCount: 1,
      cacheHit: false,
    );
  }
}

class NutritionLookupService {
  NutritionLookupService({
    FirebaseFunctions? functions,
    OpenFoodFactsService? fallbackService,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _fallbackService = fallbackService ?? OpenFoodFactsService();

  final FirebaseFunctions _functions;
  final OpenFoodFactsService _fallbackService;

  Future<NutritionProduct?> fetchProduct(String barcode) async {
    final cleanBarcode = normalizeNutritionBarcode(barcode);
    if (!isValidNutritionBarcode(cleanBarcode)) return null;

    try {
      final callable = _functions.httpsCallable('lookupNutritionByBarcode');
      final result = await callable.call<Map<String, dynamic>>({
        'barcode': cleanBarcode,
      });
      return NutritionProduct.fromCallableData(result.data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'invalid-argument') rethrow;
      if (error.code == 'not-found') return null;
      return _fetchOpenFoodFactsFallback(cleanBarcode);
    } catch (_) {
      return _fetchOpenFoodFactsFallback(cleanBarcode);
    }
  }

  Future<NutritionProduct?> _fetchOpenFoodFactsFallback(String barcode) async {
    final product = await _fallbackService.fetchProduct(barcode);
    if (product == null) return null;
    return NutritionProduct.fromOpenFoodFactsFallback(product);
  }
}

String normalizeNutritionBarcode(String value) =>
    value.replaceAll(RegExp(r'\D'), '');

bool isValidNutritionBarcode(String value) {
  final cleanBarcode = normalizeNutritionBarcode(value);
  return RegExp(r'^\d{8,14}$').hasMatch(cleanBarcode);
}

Map<String, dynamic> _stringMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, data) => MapEntry(key.toString(), data));
  }
  return const {};
}

String _stringOrDefault(Object? value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

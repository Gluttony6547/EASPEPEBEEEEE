import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_constants.dart';

class FoodProduct {
  const FoodProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.serving,
    required this.sugarPer100g,
    required this.sugarPerServing,
  });

  final String barcode;
  final String name;
  final String brand;
  final String serving;
  final double? sugarPer100g;
  final double? sugarPerServing;

  double? get suggestedSugarGram => sugarPerServing ?? sugarPer100g;
}

class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<FoodProduct?> fetchProduct(String barcode) async {
    final cleanBarcode = barcode.replaceAll(RegExp(r'\D'), '');
    if (cleanBarcode.isEmpty) return null;

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$cleanBarcode.json',
      {
        'fields':
            'code,status,product_name,brands,serving_size,serving_size_imported,nutriments,sugars_100g,sugars_serving',
      },
    );

    final response = await _client
        .get(uri, headers: {'User-Agent': AppConstants.openFoodFactsUserAgent})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception(
        'Open Food Facts gagal merespons (${response.statusCode}).',
      );
    }
    return parseOpenFoodFactsProduct(response.body, cleanBarcode);
  }
}

FoodProduct? parseOpenFoodFactsProduct(String body, String fallbackBarcode) {
  final payload = jsonDecode(body) as Map<String, dynamic>;
  if (payload['status'] != 1) return null;
  final product = payload['product'] as Map<String, dynamic>?;
  if (product == null) return null;

  final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
  final serving = _stringOrDefault(
    product['serving_size'] ?? product['serving_size_imported'],
    '1 porsi',
  );
  final sugarPer100g =
      _doubleOrNull(nutriments['sugars_100g']) ??
      _doubleOrNull(product['sugars_100g']);
  final sugarPerServing =
      _doubleOrNull(nutriments['sugars_serving']) ??
      _doubleOrNull(product['sugars_serving']) ??
      _estimateSugarPerServing(sugarPer100g: sugarPer100g, serving: serving);
  return FoodProduct(
    barcode: (product['code'] ?? fallbackBarcode).toString(),
    name: _stringOrDefault(product['product_name'], 'Produk tanpa nama'),
    brand: _stringOrDefault(product['brands'], 'Brand tidak tersedia'),
    serving: serving,
    sugarPer100g: sugarPer100g,
    sugarPerServing: sugarPerServing,
  );
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

double? _estimateSugarPerServing({
  required double? sugarPer100g,
  required String serving,
}) {
  if (sugarPer100g == null || sugarPer100g <= 0) return null;
  final match = RegExp(
    r'(\d+(?:[,.]\d+)?)\s*g\b',
    caseSensitive: false,
  ).firstMatch(serving);
  if (match == null) return null;
  final grams = _doubleOrNull(match.group(1));
  if (grams == null || grams <= 0) return null;
  return sugarPer100g * grams / 100;
}

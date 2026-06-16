import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_constants.dart';

class FoodProduct {
  const FoodProduct({
    required this.barcode,
    required this.name,
    required this.brand,
    required this.sugarPer100g,
    required this.sugarPerServing,
  });

  final String barcode;
  final String name;
  final String brand;
  final double? sugarPer100g;
  final double? sugarPerServing;

  double? get suggestedSugarGram => sugarPerServing ?? sugarPer100g;
}

class OpenFoodFactsService {
  OpenFoodFactsService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<FoodProduct?> fetchProduct(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$cleanBarcode.json',
      {
        'fields':
            'code,status,product_name,brands,nutriments,sugars_100g,sugars_serving',
      },
    );

    final response = await _client.get(
      uri,
      headers: {'User-Agent': AppConstants.openFoodFactsUserAgent},
    );
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
  return FoodProduct(
    barcode: (product['code'] ?? fallbackBarcode).toString(),
    name: _stringOrDefault(product['product_name'], 'Produk tanpa nama'),
    brand: _stringOrDefault(product['brands'], 'Brand tidak tersedia'),
    sugarPer100g: _doubleOrNull(nutriments['sugars_100g']),
    sugarPerServing: _doubleOrNull(nutriments['sugars_serving']),
  );
}

String _stringOrDefault(Object? value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

double? _doubleOrNull(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

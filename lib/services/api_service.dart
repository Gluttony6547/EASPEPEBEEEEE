import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const _baseUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const _headers = {
    'User-Agent': 'GulaDar - Android - v1.0',
  };

  /// Cari produk makanan berdasarkan nama
  /// Kembalikan list produk dengan info gula
  static Future<List<Map<String, dynamic>>> searchFood(String query) async {
    final uri = Uri.parse(
      '$_baseUrl?search_terms=${Uri.encodeComponent(query)}'
      '&search_simple=1&action=process&json=1&page_size=5',
    );

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final products = data['products'] as List? ?? [];

    return products
        .where((p) => p['nutriments']?['sugars_100g'] != null)
        .map((p) => {
              'name': p['product_name'] ?? 'Tidak diketahui',
              'brand': p['brands'] ?? '',
              'sugars100g': (p['nutriments']['sugars_100g'] as num).toDouble(),
              'servingSize': p['serving_size'] ?? '100g',
            })
        .toList();
  }

  /// Hitung gram gula dari porsi user
  static double calculateSugar(double sugars100g, double portionGram) {
    return (sugars100g * portionGram) / 100;
  }
}
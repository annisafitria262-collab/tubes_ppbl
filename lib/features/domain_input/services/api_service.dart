import 'package:dio/dio.dart';
import '../models/makanan_model.dart';

class OpenFoodFactsService {
  final Dio _dio = Dio();

  // Fungsi untuk mencari makanan berdasarkan input user
  Future<List<MakananModel>> searchFoodItem(String query) async {
    try {
      final response = await _dio.get(
        'https://world.openfoodfacts.org/cgi/search.pl',
        queryParameters: {
          'search_terms': query,
          'json': 1,
          'page_size': 10, // Ambil 10 hasil teratas saja agar ringan
        },
      );

      if (response.statusCode == 200) {
        final List products = response.data['products'];
        
        return products.map((json) {
          final nutriments = json['nutriments'] ?? {};
          
          return MakananModel(
            nama: json['product_name'] ?? 'Tanpa Nama',
            kaloriPer100g: (nutriments['energy-kcal_100g'] ?? 0).toDouble(),
            proteinG: (nutriments['proteins_100g'] ?? 0).toDouble(),
            karboG: (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
            lemakG: (nutriments['fat_100g'] ?? 0).toDouble(),
            satuanDefault: 'gram',
            sumber: 'open_food_facts', // Menandai bahwa ini dari API
          );
        }).where((makanan) => makanan.kaloriPer100g > 0).toList(); 
        // Filter: hanya tampilkan makanan yang punya data kalori valid
      }
    } catch (e) {
      print('Error fetching data from Open Food Facts: $e');
    }
    return [];
  }
}
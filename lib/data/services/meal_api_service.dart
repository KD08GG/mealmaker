import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class MealApiService {
  static Future<List<Recipe>> searchByIngredients(List<String> ingredients) async {
    final Set<String> ids = {};

    for (final ingredient in ingredients) {
      final url = Uri.parse(
        'https://www.themealdb.com/api/json/v1/1/filter.php?i=$ingredient',
      );

      try {
        final res = await http.get(url).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data["meals"] != null) {
            for (var m in data["meals"]) {
              ids.add(m["idMeal"]);
            }
          }
        }
      } catch (_) {}

      // Avoid collecting too many candidates
      if (ids.length > 60) break;
    }

    final List<Recipe> recipes = [];

    for (var id in ids) {
      final url = Uri.parse(
        'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$id',
      );

      try {
        final res = await http.get(url).timeout(const Duration(seconds: 6));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final meal = data["meals"][0];

          List<String> ings = [];
          for (int i = 1; i <= 20; i++) {
            final ing = meal["strIngredient$i"];
            if (ing != null && ing.toString().trim().isNotEmpty) {
              ings.add(ing.toString().toLowerCase().trim());
            }
          }

          recipes.add(
            Recipe(
              name: meal["strMeal"],
              instructions: meal["strInstructions"] ?? "",
              ingredients: ings,
              sourceId: id,
            ),
          );
        }
      } catch (_) {}

      if (recipes.length > 80) break;
    }

    return recipes;
  }
}

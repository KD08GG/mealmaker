import '../database/recipe_dao.dart';
import '../services/meal_api_service.dart';
import '../models/recipe.dart';
import 'dart:math';

class RecipeRepository {
  final RecipeDao dao;

  RecipeRepository(this.dao);

  Future<List<Map<String, dynamic>>> searchRecipes(List<String> tokens) async {
    // Get local recipes from SQLite
    final local = await dao.getAllRecipes();

    // Get remote recipes from API
    final remote = await MealApiService.searchByIngredients(tokens);

    // Combine both sources
    final all = [...local, ...remote];

    final userSet = tokens.toSet();
    final scored = <Map<String, dynamic>>[];

    for (final r in all) {
      final rSet = r.ingredients.map((e) => e.toLowerCase()).toSet();

      final overlap = userSet.intersection(rSet).length;
      final score = overlap / max(1, rSet.length);
      final missing = rSet.difference(userSet).toList();

      scored.add({
        "recipe": r,
        "score": score,
        "name": r.name,
        "ingredients": r.ingredients,
        "instructions": r.instructions,
        "missing": missing,
        "sourceId": r.sourceId ?? '',
      });
    }

    scored.sort((a, b) => (b["score"]).compareTo(a["score"]));

    return scored
        .where((e) => e["score"] > 0)
        .toList();
  }

  Future<List<Recipe>> getAllLocalRecipes() async {
    return await dao.getAllRecipes();
  }
}

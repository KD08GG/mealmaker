import 'package:sqflite/sqflite.dart';
import '../models/recipe.dart';
import 'app_database.dart';

class RecipeDao {
  Future<int> insertRecipe(Recipe recipe) async {
    final db = await AppDatabase.database;
    return await db.insert('recipes', recipe.toMap());
  }

  Future<List<Recipe>> getAllRecipes() async {
    final db = await AppDatabase.database;
    final maps = await db.query('recipes');
    return maps.map((e) => Recipe.fromMap(e)).toList();
  }

  Future<void> insertInitialRecipes(List<Recipe> list) async {
    final db = await AppDatabase.database;

    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM recipes'),
    );

    if (count! > 0) return;

    for (var r in list) {
      await insertRecipe(r);
    }
  }
}

import '../models/recipe.dart';
import '../repositories/recipe_repository.dart';

class SearchService {
  final RecipeRepository repo;

  SearchService(this.repo);

  Future<List<Map<String, dynamic>>> search(String userText) async {
    final tokens = userText
        .toLowerCase()
        .replaceAll(",", " ")
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();

    return await repo.searchRecipes(tokens);
  }
}

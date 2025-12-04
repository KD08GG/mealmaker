class Recipe {
  final int? id;
  final String name;
  final List<String> ingredients;
  final String instructions;
  final String? sourceId; // For API recipes (MealDB)

  Recipe({
    this.id,
    required this.name,
    required this.ingredients,
    required this.instructions,
    this.sourceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ingredients': ingredients.join(','),
      'instructions': instructions,
      'sourceId': sourceId,
    };
  }

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'],
      name: map['name'],
      ingredients: map['ingredients'].split(','),
      instructions: map['instructions'],
      sourceId: map['sourceId'],
    );
  }
}

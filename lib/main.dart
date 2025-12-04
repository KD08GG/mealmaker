import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart'; // for optional platform channels (vosk)
import 'package:http/http.dart' as http;

// Import new data layer
import 'data/models/recipe.dart';
import 'data/database/recipe_dao.dart';
import 'data/repositories/recipe_repository.dart';
import 'data/repositories/initial_recipes.dart';
import 'data/services/search_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Necesario para Windows / Linux / Desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  runApp(const MealMakerApp());
}

class AppViewport extends StatelessWidget {
  const AppViewport({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Simulated mobile width
        const double mobileWidth = 430;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: mobileWidth),
            child: const MainShell(),
          ),
        );
      },
    );
  }
}

class MealMakerApp extends StatelessWidget {
  const MealMakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MealMaker',
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
      ),
      home: const AppViewport(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final TextEditingController inputController = TextEditingController();
  bool isLoading = false;
  String loadingLabel = "Looking for best recipes…";
  List<Map<String, dynamic>> allMatches = []; // full match list
  int displayCount = 3; // number to show initially
  bool searchActive = false; // when true, search bar is hidden and results show
  final Set<String> favorites = {}; // recipe names
  static const platform = MethodChannel('com.example.mealmaker/vosk');

  // New data layer instances
  late RecipeRepository repository;
  late SearchService searchService;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    final dao = RecipeDao();

    // Insert initial 50 recipes if database is empty
    await dao.insertInitialRecipes(initialRecipes);

    repository = RecipeRepository(dao);
    searchService = SearchService(repository);

    setState(() {
      isInitialized = true;
    });
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  Future<void> startSearch(String rawIngredients) async {
    if (rawIngredients.trim().isEmpty) {
      _showWarning("Please type some ingredients or use the mic.");
      return;
    }

    if (!isInitialized) {
      _showWarning("Database is initializing, please wait...");
      return;
    }

    setState(() {
      isLoading = true;
      loadingLabel = "Looking for best recipes…";
    });

    await Future.delayed(const Duration(milliseconds: 250));

    try {
      // Use new search service (SQLite + API + natural language)
      final results = await searchService.search(rawIngredients);

      setState(() {
        allMatches = results.where((m) => (m['score'] as double) > 0).toList();
        displayCount = min(3, allMatches.length);
        searchActive = true;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        allMatches = [];
        searchActive = true;
        isLoading = false;
      });
      _showWarning("Search failed: ${e.toString()}");
    }
  }

  void loadMore() {
    setState(() {
      displayCount = min(displayCount + 5, allMatches.length);
    });
  }

  void clearSearch() {
    setState(() {
      inputController.clear();
      allMatches = [];
      displayCount = 3;
      searchActive = false;
    });
  }

  Future<void> startVoiceRecognition() async {
    setState(() {
      isLoading = true;
      loadingLabel = "Listening… speak now";
    });
    try {
      final String recognized =
          await platform.invokeMethod<String>('startVoskRecognition') ?? '';
      if (recognized.isNotEmpty) {
        inputController.text = recognized;
        await Future.delayed(const Duration(milliseconds: 50));
        await startSearch(recognized);
      } else {
        _showWarning("No speech detected.");
      }
    } on PlatformException catch (e) {
      _showWarning("Voice recognition not available: ${e.message}");
    } finally {
      setState(() {
        isLoading = false;
        loadingLabel = "Looking for best recipes…";
      });
    }
  }

  void _showWarning(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.orange),
    );
  }

  void _showInfo(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: Colors.green),
    );
  }

  Future<void> openDetails(Map<String, dynamic> recipe) async {
    final res = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailsPage(
          recipe: recipe,
          isFavorite: favorites.contains(recipe['name']),
          onToggleFavorite: (name, add) {
            setState(() {
              if (add)
                favorites.add(name);
              else
                favorites.remove(name);
            });
          },
        ),
      ),
    );
    if (res == 'cook') {
      setState(() => isLoading = true);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => isLoading = false);
      _showInfo('All set to cook ${recipe['name']} — enjoy!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Treat as vertical (portrait) by default; adapt when window is wider than tall
        final bool isPortrait = constraints.maxHeight >= constraints.maxWidth;
        final double thumbSize = isPortrait ? 110.0 : 140.0;
        final double cardHeight = isPortrait ? 120.0 : 140.0;

        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          "🍽️ MealMaker",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (!searchActive)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: inputController,
                                style: const TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: "tell me what ingredients you have",
                                  hintStyle: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14.0,
                                    horizontal: 14.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: isPortrait ? 56 : 64,
                              height: isPortrait ? 56 : 64,
                              child: ElevatedButton(
                                onPressed: startVoiceRecognition,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6A00),
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${allMatches.length} matches',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: clearSearch,
                                child: const Text('New search'),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: searchActive
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Vertical results list (portrait mobile proportions)
                                  Expanded(
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      itemCount: displayCount,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 10),
                                      itemBuilder: (context, index) {
                                        final r = allMatches[index];
                                        return SizedBox(
                                          height: cardHeight,
                                          child: Card(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                // thumbnail adapts to portrait/landscape
                                                Container(
                                                  width: thumbSize,
                                                  height: thumbSize,
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade300,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                  ),
                                                  child: const Center(
                                                    child: Text(
                                                      'Not available',
                                                      style: TextStyle(
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12.0,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          r['name'] ?? '',
                                                          style: TextStyle(
                                                            fontSize: isPortrait
                                                                ? 16
                                                                : 18,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          'Match: ${((r['score'] ?? 0.0) * 100).round()}%',
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFE66A00,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        if (r['missing'] !=
                                                                null &&
                                                            (r['missing']
                                                                    as List)
                                                                .isNotEmpty)
                                                          Text(
                                                            'Needed: ${(r['missing'] as List).take(3).join(", ")}${(r['missing'] as List).length > 3 ? ', ...' : ''}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white70,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        const Spacer(),
                                                        Align(
                                                          alignment: Alignment
                                                              .centerRight,
                                                          child: ElevatedButton(
                                                            onPressed: () =>
                                                                openDetails(r),
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.green,
                                                            ),
                                                            child: const Text(
                                                              'Cook',
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (displayCount < allMatches.length)
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: loadMore,
                                        child: const Text('Load more'),
                                      ),
                                    )
                                  else if (allMatches.isEmpty)
                                    const Center(
                                      child: Text(
                                        'No matches found',
                                        style: TextStyle(color: Colors.white60),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                ],
                              )
                            : Center(
                                child: Text(
                                  "No results yet. Search to see suggestions.",
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      ),

                      const Divider(color: Colors.white12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                if (isInitialized) {
                                  final allRecipes = await repository.getAllLocalRecipes();
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SeeAllPage(
                                        recipes: allRecipes,
                                        onCook: openDetails,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showWarning("Database is initializing...");
                                }
                              },
                              icon: const Icon(
                                Icons.grid_view,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'See all recipes',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                clearSearch();
                              },
                              icon: const Icon(Icons.home, color: Colors.white),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                if (isInitialized) {
                                  final allRecipes = await repository.getAllLocalRecipes();
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => SavedPage(
                                        recipes: allRecipes,
                                        favorites: favorites,
                                        onCook: openDetails,
                                      ),
                                    ),
                                  );
                                } else {
                                  _showWarning("Database is initializing...");
                                }
                              },
                              icon: const Icon(
                                Icons.bookmark,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Saved Recipes',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (isLoading)
                Center(
                  child: Container(
                    width: 320,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spinner(diameter: 80),
                        const SizedBox(height: 12),
                        Text(
                          loadingLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// -----------------------------
/// See All Page: grid of flip cards
/// -----------------------------
class SeeAllPage extends StatelessWidget {
  final List<Recipe> recipes;
  final Future<void> Function(Map<String, dynamic>) onCook;
  const SeeAllPage({super.key, required this.recipes, required this.onCook});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: const Text('All Recipes', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.8,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final r = recipes[index];
            return FlipCard(
              front: _buildFront(r),
              back: _buildBack(r, context),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(Recipe r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 48, color: Colors.black38),
          const SizedBox(height: 8),
          Text(
            r.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(Recipe r, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            r.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingredients: ${r.ingredients.take(4).join(", ")}',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Center(
            child: ElevatedButton(
              onPressed: () => onCook({
                'name': r.name,
                'ingredients': r.ingredients,
                'instructions': r.instructions,
                'score': 1.0,
                'missing': [],
              }),
              child: const Text('Cook'),
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------
/// Saved Page: grid of favorites only
/// -----------------------------
class SavedPage extends StatelessWidget {
  final List<Recipe> recipes;
  final Set<String> favorites;
  final Future<void> Function(Map<String, dynamic>) onCook;
  const SavedPage({
    super.key,
    required this.recipes,
    required this.favorites,
    required this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    final favRecipes = recipes
        .where((r) => favorites.contains(r.name))
        .toList();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: const Text('My Recipes', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: favRecipes.isEmpty
            ? const Center(
                child: Text(
                  'No saved recipes yet',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemCount: favRecipes.length,
                itemBuilder: (context, index) {
                  final r = favRecipes[index];
                  return FlipCard(
                    front: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          r.name,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    back: Container(
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: ElevatedButton(
                              onPressed: () => onCook({
                                'name': r.name,
                                'ingredients': r.ingredients,
                                'instructions': r.instructions,
                                'score': 1.0,
                                'missing': [],
                              }),
                              child: const Text('Cook'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// -----------------------------
/// Recipe details / cook page (with favorite toggle)
/// -----------------------------
class RecipeDetailsPage extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final bool isFavorite;
  final void Function(String name, bool add) onToggleFavorite;
  const RecipeDetailsPage({
    super.key,
    required this.recipe,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late bool favorite;

  @override
  void initState() {
    favorite = widget.isFavorite;
    super.initState();
  }

  void toggleFav() {
    setState(() => favorite = !favorite);
    widget.onToggleFavorite(widget.recipe['name'], favorite);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: BackButton(color: Colors.white),
        title: Text(
          r['name'] ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            onPressed: toggleFav,
            icon: Icon(
              favorite ? Icons.star : Icons.star_border,
              color: Colors.white,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r['name'] ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingredients:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${(r['ingredients'] as List).join("\n• ")}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'Instructions:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              r['instructions'] ?? '',
              style: const TextStyle(color: Colors.white),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop('cook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Cook This',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------
/// Flip card (basic) implementation
/// -----------------------------
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  const FlipCard({super.key, required this.front, required this.back});

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_showFront) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
    setState(() => _showFront = !_showFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final angle = _ctrl.value * pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle);
          final isFrontVisible = _ctrl.value < 0.5;
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Container(
              child: isFrontVisible
                  ? widget.front
                  : Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: widget.back,
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// -----------------------------
/// Spinner from original file
/// -----------------------------
class Spinner extends StatefulWidget {
  final double diameter;
  const Spinner({super.key, this.diameter = 80});

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.diameter,
      height: widget.diameter,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return CustomPaint(painter: _SpinnerPainter(rotation: _ctrl.value));
        },
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  final double rotation;
  _SpinnerPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) / 2) - 6;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * pi);

    final paint = Paint()..style = PaintingStyle.fill;
    const int segments = 8;
    for (int i = 0; i < segments; i++) {
      final alpha = ((i + 1) / segments);
      paint.color = const Color(0xFFFF8A40).withOpacity(alpha.toDouble());
      final angle = i * (2 * pi / segments);
      canvas.save();
      canvas.rotate(angle);
      final rect = RRect.fromLTRBR(
        radius - 8,
        -6,
        radius + 8,
        6,
        const Radius.circular(6),
      );
      canvas.drawRRect(rect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SpinnerPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}


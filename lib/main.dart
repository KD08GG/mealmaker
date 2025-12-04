import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart'; // for optional platform channels (vosk)
import 'package:http/http.dart' as http;

void main() {
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
  bool apiAvailable = false;

  @override
  void initState() {
    super.initState();
    // check API availability in background
    _checkApiAvailable();
  }

  Future<void> _checkApiAvailable() async {
    try {
      final uri = Uri.parse(
        'https://www.themealdb.com/api/json/v1/1/search.php?s=',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        setState(() => apiAvailable = true);
        return;
      }
    } catch (_) {}
    setState(() => apiAvailable = false);
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
    setState(() {
      isLoading = true;
      loadingLabel = "Looking for best recipes…";
    });

    final tokens = rawIngredients
        .toLowerCase()
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .map((s) => normalizeIngredient(s))
        .where((s) => s.isNotEmpty)
        .toList();

    await Future.delayed(const Duration(milliseconds: 250));

    // Fetch candidate recipes from BOTH local and API
    try {
      // Always get local recipes first
      final localRecipes = recipes
          .map(
            (r) => {
              'id': r['name'],
              'name': r['name'],
              'instructions': r['instructions'],
              'ingredients': (r['ingredients'] as List)
                  .map((e) => e.toString().toLowerCase().trim())
                  .toList(),
            },
          )
          .toList();

      // Try to get API recipes
      List<Map<String, dynamic>> apiRecipes = [];
      if (!apiAvailable) await _checkApiAvailable();
      if (apiAvailable) {
        apiRecipes = await fetchRecipesFromApi(tokens);
      }

      // Combine both sources
      final allRecipes = [...localRecipes, ...apiRecipes];

      // compute scores and missing ingredients
      final userSet = tokens.toSet();
      final List<Map<String, dynamic>> scored = [];
      for (final rcp in allRecipes) {
        final rIngredients = (rcp['ingredients'] as List)
            .map((e) => normalizeIngredient(e.toString()))
            .where((s) => s.isNotEmpty)
            .toSet();
        final overlap = userSet.intersection(rIngredients).length;
        final score = overlap / max(1, rIngredients.length);
        final missing = rIngredients.difference(userSet).toList();
        scored.add({
          "name": rcp['name'],
          "score": score,
          "ingredients": rcp['ingredients'],
          "instructions": rcp['instructions'],
          "thumbnail": rcp['thumbnail'] ?? '',
          "tags": rcp['tags'] ?? [],
          "missing": missing,
          "sourceId": rcp['id'], // Distinguish local vs API
        });
      }
      scored.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );
      setState(() {
        allMatches = scored.where((m) => (m['score'] as double) > 0).toList();
        displayCount = min(3, allMatches.length);
        searchActive = true;
        isLoading = false;
      });
    } catch (e) {
      // fallback to local recipes if anything fails
      final localTokens = tokens;
      final r = suggestRecipes(localTokens, topK: recipes.length);
      setState(() {
        allMatches = r.where((m) => (m['score'] as double) > 0).toList();
        displayCount = min(3, allMatches.length);
        searchActive = true;
        isLoading = false;
      });
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
              if (add) {
                favorites.add(name);
              } else {
                favorites.remove(name);
              }
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
        final double cardHeight = isPortrait ? 140.0 : 160.0;
        final double topSpacing = isPortrait
            ? constraints.maxHeight * 0.06
            : constraints.maxHeight * 0.04;

        return Scaffold(
          body: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      SizedBox(height: topSpacing),
                      Center(
                        child: Text(
                          "🍽️ MealMaker",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: topSpacing * 0.35),

                      if (!searchActive)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: inputController,
                                style: const TextStyle(color: Colors.black),
                                onSubmitted: startSearch,
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
                                onPressed: () =>
                                    startSearch(inputController.text),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6A00),
                                  shape: const CircleBorder(),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Icon(
                                  Icons.search,
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
                                        return ResultCard(
                                          recipe: r,
                                          height: cardHeight,
                                          thumbSize: thumbSize,
                                          isPortrait: isPortrait,
                                          onCook: () => openDetails(r),
                                          onTap: () => openDetails(r),
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
                            : const SizedBox.shrink(),
                      ),

                      const Divider(color: Colors.white12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SeeAllPage(
                                      recipes: recipes,
                                      onCook: openDetails,
                                    ),
                                  ),
                                );
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
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SavedPage(
                                      recipes: recipes,
                                      favorites: favorites,
                                      onCook: openDetails,
                                    ),
                                  ),
                                );
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
  final List<Map<String, dynamic>> recipes;
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
            return GridRecipeCard(recipe: r, onCook: onCook);
          },
        ),
      ),
    );
  }
}

/// -----------------------------
/// Saved Page: grid of favorites only
/// -----------------------------
class SavedPage extends StatelessWidget {
  final List<Map<String, dynamic>> recipes;
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
        .where((r) => favorites.contains(r['name']))
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
                  return GridRecipeCard(recipe: r, onCook: onCook);
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
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  r['instructions'] ?? '',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
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
/// Spinner from original file
/// -----------------------------
class Spinner extends StatefulWidget {
  final double diameter;
  const Spinner({super.key, this.diameter = 80});

  @override
  State<Spinner> createState() => _SpinnerState();
}

/// Result card used in the main results list
class ResultCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final double height;
  final double thumbSize;
  final bool isPortrait;
  final VoidCallback onCook;
  final VoidCallback? onTap;

  const ResultCard({
    super.key,
    required this.recipe,
    required this.height,
    required this.thumbSize,
    required this.isPortrait,
    required this.onCook,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final missing = (recipe['missing'] as List?) ?? <dynamic>[];
    // Check if recipe is from API (has sourceId that's not the recipe name)
    final isFromApi = recipe['sourceId'] != null &&
                      recipe['sourceId'] != recipe['name'];

    return SizedBox(
      height: height,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isFromApi ? Colors.blue.shade400 : Colors.green.shade400,
            width: 2,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: const Icon(
                  Icons.restaurant,
                  size: 40,
                  color: Colors.black54,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        recipe['name'] ?? '',
                        style: TextStyle(
                          fontSize: isPortrait ? 16 : 18,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Match: ${((recipe['score'] ?? 0.0) * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFFE66A00),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (missing.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Needed: ${missing.take(3).join(", ")}${missing.length > 3 ? ', ...' : ''}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: onCook,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            minimumSize: const Size(60, 32),
                          ),
                          child: const Text('Cook', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid card used in See All / Saved pages
class GridRecipeCard extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final Future<void> Function(Map<String, dynamic>) onCook;
  const GridRecipeCard({super.key, required this.recipe, required this.onCook});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fastfood, size: 48, color: Colors.black38),
          const SizedBox(height: 8),
          Text(
            recipe['name'] ?? '',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => onCook(recipe),
            child: const Text('Cook'),
          ),
        ],
      ),
    );
  }
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

/// -----------------------------
/// Local recipe DB (50 RECIPES) and suggestRecipes
/// -----------------------------
final List<Map<String, dynamic>> recipes = [
  {
    "name": "Avocado Toast Deluxe",
    "ingredients": ["bread", "avocado", "salt", "pepper", "lime"],
    "instructions": "Toast bread. Mash avocado with lime, salt, pepper. Spread and serve.",
    "tags": ["breakfast", "healthy"],
  },
  {
    "name": "Garlic Butter Pasta",
    "ingredients": ["pasta", "garlic", "butter", "salt", "parsley"],
    "instructions": "Cook pasta. Melt butter with garlic. Mix with pasta and top with parsley.",
    "tags": ["lunch", "easy"],
  },
  {
    "name": "Chicken Veggie Bowl",
    "ingredients": ["chicken", "rice", "carrot", "broccoli", "soy sauce"],
    "instructions": "Cook chicken. Steam veggies. Serve over rice with soy sauce.",
    "tags": ["dinner", "healthy"],
  },
  {
    "name": "Greek Yogurt Parfait",
    "ingredients": ["yogurt", "granola", "honey", "berries", "banana"],
    "instructions": "Layer yogurt, granola, and fruit. Drizzle honey on top.",
    "tags": ["breakfast", "healthy"],
  },
  {
    "name": "Veggie Stir Fry",
    "ingredients": ["broccoli", "carrot", "pepper", "onion", "soy sauce", "garlic"],
    "instructions": "Heat oil, add garlic and veggies. Stir fry with soy sauce until tender.",
    "tags": ["vegan", "fast"],
  },
  {
    "name": "Tuna Salad Sandwich",
    "ingredients": ["tuna", "bread", "mayo", "lettuce", "tomato", "onion"],
    "instructions": "Mix tuna with mayo. Layer on bread with veggies.",
    "tags": ["lunch", "protein"],
  },
  {
    "name": "Scrambled Eggs with Toast",
    "ingredients": ["eggs", "butter", "bread", "salt", "pepper"],
    "instructions": "Whisk eggs. Scramble in butter. Serve with toasted bread.",
    "tags": ["breakfast", "fast"],
  },
  {
    "name": "Caprese Salad",
    "ingredients": ["tomato", "mozzarella", "basil", "olive oil", "salt"],
    "instructions": "Slice tomato and mozzarella. Layer with basil. Drizzle oil and salt.",
    "tags": ["salad", "fresh"],
  },
  {
    "name": "Beef Tacos",
    "ingredients": ["beef", "tortillas", "lettuce", "cheese", "tomato", "sour cream"],
    "instructions": "Brown beef with spices. Fill tortillas with beef and toppings.",
    "tags": ["mexican", "dinner"],
  },
  {
    "name": "Smoothie Bowl",
    "ingredients": ["banana", "berries", "yogurt", "granola", "honey"],
    "instructions": "Blend banana, berries, and yogurt. Top with granola and honey.",
    "tags": ["breakfast", "healthy"],
  },
  {
    "name": "Mushroom Risotto",
    "ingredients": ["rice", "mushroom", "onion", "garlic", "butter", "parmesan"],
    "instructions": "Sauté mushrooms. Cook rice slowly adding broth. Stir in butter and cheese.",
    "tags": ["italian", "dinner"],
  },
  {
    "name": "Caesar Salad",
    "ingredients": ["lettuce", "croutons", "parmesan", "caesar dressing", "lemon"],
    "instructions": "Toss lettuce with dressing. Add croutons, parmesan, and lemon juice.",
    "tags": ["salad", "classic"],
  },
  {
    "name": "Baked Salmon",
    "ingredients": ["salmon", "lemon", "garlic", "olive oil", "dill", "salt"],
    "instructions": "Season salmon with oil, garlic, lemon. Bake at 375°F for 15 minutes.",
    "tags": ["fish", "healthy"],
  },
  {
    "name": "Vegetable Soup",
    "ingredients": ["carrot", "celery", "onion", "tomato", "potato", "broth"],
    "instructions": "Chop veggies. Simmer in broth for 30 minutes until tender.",
    "tags": ["soup", "comfort"],
  },
  {
    "name": "Pancakes",
    "ingredients": ["flour", "milk", "eggs", "sugar", "butter", "baking powder"],
    "instructions": "Mix ingredients. Pour batter on griddle. Flip when bubbles form.",
    "tags": ["breakfast", "sweet"],
  },
  {
    "name": "Grilled Cheese Sandwich",
    "ingredients": ["bread", "cheese", "butter"],
    "instructions": "Butter bread. Add cheese between slices. Grill until golden.",
    "tags": ["lunch", "classic"],
  },
  {
    "name": "Chicken Quesadilla",
    "ingredients": ["chicken", "tortilla", "cheese", "pepper", "onion"],
    "instructions": "Cook chicken with veggies. Fill tortilla with mixture and cheese. Grill.",
    "tags": ["mexican", "quick"],
  },
  {
    "name": "Tomato Basil Pasta",
    "ingredients": ["pasta", "tomato", "basil", "garlic", "olive oil", "parmesan"],
    "instructions": "Cook pasta. Sauté garlic and tomatoes. Toss with pasta and basil.",
    "tags": ["italian", "vegetarian"],
  },
  {
    "name": "Breakfast Burrito",
    "ingredients": ["eggs", "tortilla", "cheese", "beans", "salsa", "avocado"],
    "instructions": "Scramble eggs. Fill tortilla with eggs, beans, cheese. Add salsa.",
    "tags": ["breakfast", "mexican"],
  },
  {
    "name": "Chicken Noodle Soup",
    "ingredients": ["chicken", "noodles", "carrot", "celery", "onion", "broth"],
    "instructions": "Simmer chicken in broth. Add veggies and noodles. Cook until tender.",
    "tags": ["soup", "comfort"],
  },
  {
    "name": "Margherita Pizza",
    "ingredients": ["pizza dough", "tomato sauce", "mozzarella", "basil", "olive oil"],
    "instructions": "Spread sauce on dough. Top with cheese and basil. Bake at 450°F.",
    "tags": ["italian", "pizza"],
  },
  {
    "name": "Shrimp Scampi",
    "ingredients": ["shrimp", "garlic", "butter", "lemon", "parsley", "pasta"],
    "instructions": "Sauté shrimp in garlic butter. Add lemon and parsley. Serve over pasta.",
    "tags": ["seafood", "italian"],
  },
  {
    "name": "Chicken Fried Rice",
    "ingredients": ["rice", "chicken", "eggs", "peas", "carrot", "soy sauce"],
    "instructions": "Stir fry chicken. Add rice, veggies, and scrambled eggs. Season with soy sauce.",
    "tags": ["asian", "dinner"],
  },
  {
    "name": "BBQ Chicken Wings",
    "ingredients": ["chicken wings", "bbq sauce", "garlic powder", "salt", "pepper"],
    "instructions": "Season wings. Bake at 400°F for 40 minutes. Toss in BBQ sauce.",
    "tags": ["appetizer", "party"],
  },
  {
    "name": "Beef Stir Fry",
    "ingredients": ["beef", "broccoli", "carrot", "onion", "soy sauce", "ginger"],
    "instructions": "Slice beef. Stir fry with veggies and ginger. Add soy sauce.",
    "tags": ["asian", "dinner"],
  },
  {
    "name": "French Toast",
    "ingredients": ["bread", "eggs", "milk", "cinnamon", "sugar", "butter"],
    "instructions": "Whisk eggs with milk and cinnamon. Dip bread. Fry in butter.",
    "tags": ["breakfast", "sweet"],
  },
  {
    "name": "Chicken Caesar Wrap",
    "ingredients": ["chicken", "tortilla", "lettuce", "parmesan", "caesar dressing"],
    "instructions": "Grill chicken. Fill tortilla with lettuce, chicken, cheese. Drizzle dressing.",
    "tags": ["lunch", "wrap"],
  },
  {
    "name": "Spaghetti Carbonara",
    "ingredients": ["spaghetti", "bacon", "eggs", "parmesan", "pepper", "garlic"],
    "instructions": "Cook pasta. Fry bacon. Mix eggs and cheese. Toss hot pasta with mixture.",
    "tags": ["italian", "pasta"],
  },
  {
    "name": "Veggie Omelette",
    "ingredients": ["eggs", "pepper", "onion", "mushroom", "cheese", "salt"],
    "instructions": "Whisk eggs. Pour in pan. Add veggies and cheese. Fold and serve.",
    "tags": ["breakfast", "vegetarian"],
  },
  {
    "name": "Fish Tacos",
    "ingredients": ["fish", "tortilla", "cabbage", "lime", "sour cream", "cilantro"],
    "instructions": "Grill fish. Fill tortillas. Top with cabbage, lime, and cream.",
    "tags": ["mexican", "seafood"],
  },
  {
    "name": "Beef Burger",
    "ingredients": ["beef", "bun", "lettuce", "tomato", "cheese", "onion"],
    "instructions": "Form patties. Grill beef. Assemble burger with toppings.",
    "tags": ["american", "grill"],
  },
  {
    "name": "Chicken Teriyaki",
    "ingredients": ["chicken", "teriyaki sauce", "rice", "broccoli", "sesame seeds"],
    "instructions": "Cook chicken in teriyaki sauce. Serve over rice with broccoli.",
    "tags": ["asian", "dinner"],
  },
  {
    "name": "Mac and Cheese",
    "ingredients": ["pasta", "cheese", "milk", "butter", "flour", "salt"],
    "instructions": "Cook pasta. Make cheese sauce with milk, butter, flour. Mix together.",
    "tags": ["comfort", "classic"],
  },
  {
    "name": "Shrimp Tacos",
    "ingredients": ["shrimp", "tortilla", "cabbage", "avocado", "lime", "cilantro"],
    "instructions": "Sauté shrimp. Fill tortillas. Top with cabbage and avocado.",
    "tags": ["mexican", "seafood"],
  },
  {
    "name": "Chicken Alfredo",
    "ingredients": ["chicken", "pasta", "cream", "parmesan", "garlic", "butter"],
    "instructions": "Cook chicken and pasta. Make alfredo sauce with cream and cheese. Combine.",
    "tags": ["italian", "creamy"],
  },
  {
    "name": "Egg Fried Rice",
    "ingredients": ["rice", "eggs", "peas", "carrot", "soy sauce", "onion"],
    "instructions": "Scramble eggs. Stir fry rice with veggies. Add eggs and soy sauce.",
    "tags": ["asian", "vegetarian"],
  },
  {
    "name": "Pork Chops",
    "ingredients": ["pork chops", "garlic", "rosemary", "olive oil", "salt", "pepper"],
    "instructions": "Season pork. Sear in oil with garlic and rosemary until cooked.",
    "tags": ["dinner", "meat"],
  },
  {
    "name": "Chicken Fajitas",
    "ingredients": ["chicken", "pepper", "onion", "tortilla", "lime", "cilantro"],
    "instructions": "Slice chicken and veggies. Stir fry. Serve in tortillas with lime.",
    "tags": ["mexican", "dinner"],
  },
  {
    "name": "Minestrone Soup",
    "ingredients": ["beans", "pasta", "tomato", "carrot", "celery", "onion"],
    "instructions": "Sauté veggies. Add beans, tomatoes, broth. Simmer with pasta.",
    "tags": ["soup", "italian"],
  },
  {
    "name": "Turkey Sandwich",
    "ingredients": ["turkey", "bread", "lettuce", "tomato", "mayo", "cheese"],
    "instructions": "Layer turkey on bread with veggies and mayo.",
    "tags": ["lunch", "sandwich"],
  },
  {
    "name": "Beef Stroganoff",
    "ingredients": ["beef", "mushroom", "onion", "sour cream", "noodles", "butter"],
    "instructions": "Brown beef. Sauté mushrooms and onions. Add sour cream. Serve over noodles.",
    "tags": ["russian", "comfort"],
  },
  {
    "name": "Chicken Parmesan",
    "ingredients": ["chicken", "tomato sauce", "mozzarella", "parmesan", "pasta", "basil"],
    "instructions": "Bread and fry chicken. Top with sauce and cheese. Bake. Serve over pasta.",
    "tags": ["italian", "classic"],
  },
  {
    "name": "Vegetable Curry",
    "ingredients": ["potato", "carrot", "peas", "curry powder", "coconut milk", "onion"],
    "instructions": "Sauté onion. Add veggies and curry powder. Simmer in coconut milk.",
    "tags": ["indian", "vegan"],
  },
  {
    "name": "BLT Sandwich",
    "ingredients": ["bacon", "lettuce", "tomato", "bread", "mayo"],
    "instructions": "Fry bacon. Layer on toasted bread with lettuce, tomato, and mayo.",
    "tags": ["lunch", "classic"],
  },
  {
    "name": "Chicken Salad",
    "ingredients": ["chicken", "lettuce", "tomato", "cucumber", "ranch dressing", "croutons"],
    "instructions": "Grill chicken. Toss lettuce and veggies. Top with chicken and dressing.",
    "tags": ["salad", "healthy"],
  },
  {
    "name": "Beef Chili",
    "ingredients": ["beef", "beans", "tomato", "onion", "chili powder", "garlic"],
    "instructions": "Brown beef. Add beans, tomatoes, spices. Simmer for 30 minutes.",
    "tags": ["soup", "spicy"],
  },
  {
    "name": "Pad Thai",
    "ingredients": ["noodles", "shrimp", "eggs", "peanuts", "lime", "soy sauce"],
    "instructions": "Cook noodles. Stir fry shrimp and eggs. Toss with noodles and sauce.",
    "tags": ["thai", "asian"],
  },
  {
    "name": "Chicken Enchiladas",
    "ingredients": ["chicken", "tortilla", "cheese", "enchilada sauce", "onion", "sour cream"],
    "instructions": "Fill tortillas with chicken and cheese. Cover with sauce. Bake at 350°F.",
    "tags": ["mexican", "dinner"],
  },
  {
    "name": "Meatball Sub",
    "ingredients": ["meatballs", "bread", "tomato sauce", "mozzarella", "parmesan"],
    "instructions": "Cook meatballs in sauce. Place in bread. Top with cheese and broil.",
    "tags": ["sandwich", "italian"],
  },
  {
    "name": "Lemon Herb Chicken",
    "ingredients": ["chicken", "lemon", "thyme", "garlic", "olive oil", "salt"],
    "instructions": "Marinate chicken in lemon and herbs. Grill or bake until cooked.",
    "tags": ["dinner", "healthy"],
  },
];

List<Map<String, dynamic>> suggestRecipes(
  List<String> userIngredients, {
  int topK = 3,
}) {
  final userSet = userIngredients.map((e) => e.trim().toLowerCase()).toSet();
  final List<Map<String, dynamic>> scored = [];
  for (final r in recipes) {
    final rSet = (r['ingredients'] as List)
        .map((e) => e.toString().toLowerCase())
        .toSet();
    final overlap = userSet.intersection(rSet).length;
    final score = overlap / max(1, rSet.length);
    scored.add({
      "name": r['name'],
      "score": score,
      "ingredients": r['ingredients'],
      "instructions": r['instructions'],
      "sourceId": r['name'], // Local recipes use name as sourceId
    });
  }
  scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  return scored.take(topK).toList();
}

/// Normalize ingredient tokens: lowercase, strip punctuation and quantities
String normalizeIngredient(String s) {
  var out = s.toLowerCase().trim();
  // remove measurements/numbers (basic)
  out = out.replaceAll(RegExp(r"\b\d+\b"), '');
  out = out.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  out = out.replaceAll(RegExp(r'\s+'), ' ').trim();
  // naive singular: drop trailing 's' for simple plural words
  if (out.length > 3 && out.endsWith('s')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// Fetch recipes from TheMealDB API by searching for each ingredient token,
/// then fetching full meal details to extract the ingredient list.
Future<List<Map<String, dynamic>>> fetchRecipesFromApi(
  List<String> tokens,
) async {
  final Set<String> ids = {};
  for (final token in tokens) {
    final q = Uri.encodeComponent(token);
    final url = Uri.parse(
      'https://www.themealdb.com/api/json/v1/1/filter.php?i=$q',
    );
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final meals = data['meals'];
        if (meals != null && meals is List) {
          for (final m in meals) {
            final id = m['idMeal']?.toString();
            if (id != null) ids.add(id);
          }
        }
      }
    } catch (_) {
      // ignore per-token failures and continue
    }
    // avoid collecting too many candidates
    if (ids.length > 60) break;
  }

  final List<Map<String, dynamic>> out = [];
  for (final id in ids) {
    final url = Uri.parse(
      'https://www.themealdb.com/api/json/v1/1/lookup.php?i=$id',
    );
    try {
      final resp = await http.get(url).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final meals = data['meals'];
        if (meals != null && meals is List && meals.isNotEmpty) {
          final m = meals.first;
          final name = m['strMeal'] ?? '';
          final instructions = m['strInstructions'] ?? '';
          final List<String> ingredients = [];
          for (var i = 1; i <= 20; i++) {
            final key = 'strIngredient$i';
            final ing = m[key];
            if (ing != null && ing.toString().trim().isNotEmpty) {
              ingredients.add(ing.toString().toLowerCase().trim());
            }
          }
          out.add({
            'id': id,
            'name': name,
            'instructions': instructions,
            'ingredients': ingredients,
            'thumbnail': m['strMealThumb'] ?? '',
            'tags': m['strTags'] ?? '',
            'category': m['strCategory'] ?? '',
          });
        }
      }
    } catch (_) {
      // ignore per-id failures
    }
    if (out.length > 80) break;
  }

  return out;
}

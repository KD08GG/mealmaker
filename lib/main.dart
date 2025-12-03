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
        .where((s) => s.trim().isNotEmpty)
        .toList();

    await Future.delayed(const Duration(milliseconds: 250));

    // Fetch candidate recipes from remote API (TheMealDB) and compute scores
    try {
      final remote = await fetchRecipesFromApi(tokens);
      // compute scores and missing ingredients
      final userSet = tokens.toSet();
      final List<Map<String, dynamic>> scored = [];
      for (final rcp in remote) {
        final rIngredients = (rcp['ingredients'] as List)
            .map((e) => e.toString().toLowerCase().trim())
            .toSet();
        final overlap = userSet.intersection(rIngredients).length;
        final score = overlap / max(1, rIngredients.length);
        final missing = rIngredients.difference(userSet).toList();
        scored.add({
          'name': rcp['name'],
          'score': score,
          'ingredients': rcp['ingredients'],
          'instructions': rcp['instructions'] ?? '',
          'missing': missing,
          'sourceId': rcp['id'] ?? '',
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
      // fallback to local recipes if API fails
      final r = suggestRecipes(tokens, topK: recipes.length);
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
            return FlipCard(
              front: _buildFront(r),
              back: _buildBack(r, context),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFront(Map<String, dynamic> r) {
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
            r['name'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBack(Map<String, dynamic> r, BuildContext context) {
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
            r['name'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingredients: ${(r['ingredients'] as List).take(4).join(", ")}',
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Center(
            child: ElevatedButton(
              onPressed: () => onCook(r),
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
                  return FlipCard(
                    front: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          r['name'] ?? '',
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
                            r['name'] ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: ElevatedButton(
                              onPressed: () => onCook(r),
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

/// -----------------------------
/// Local recipe DB and suggestRecipes
/// -----------------------------
final List<Map<String, dynamic>> recipes = [
  {
    "name": "Vegetable Omelette",
    "ingredients": ["eggs", "onion", "tomato", "spinach", "salt", "pepper"],
    "instructions":
        "Whisk eggs. Cook chopped veggies in a pan. Add eggs and fold.",
    "tags": ["breakfast", "fast", "healthy"],
  },
  {
    "name": "Pasta with Tomato Sauce",
    "ingredients": ["pasta", "tomato", "garlic", "olive oil", "salt", "basil"],
    "instructions": "Boil pasta. Simmer garlic and tomato sauce. Mix.",
    "tags": ["lunch", "easy"],
  },
  {
    "name": "Mexican Chicken Tacos",
    "ingredients": ["chicken", "tortillas", "onion", "cilantro", "lime"],
    "instructions": "Sauté chicken. Warm tortillas. Add toppings.",
    "tags": ["latin", "protein"],
  },
  {
    "name": "Lentil Soup",
    "ingredients": ["lentils", "carrot", "onion", "celery", "garlic", "salt"],
    "instructions": "Simmer all ingredients for 30 min.",
    "tags": ["vegan", "cheap", "batch-cooking"],
  },
  {
    "name": "Fried Rice",
    "ingredients": ["rice", "egg", "carrot", "pea", "soy sauce", "onion"],
    "instructions": "Stir fry ingredients in wok.",
    "tags": ["asian", "use-leftovers"],
  },
  {
    "name": "Chicken Rice Bowl",
    "ingredients": ["rice", "chicken", "soy sauce", "carrot", "onion"],
    "instructions": "Cook rice. Stir fry chicken and veggies.",
    "tags": ["balanced"],
  },
  {
    "name": "Guacamole",
    "ingredients": ["avocado", "onion", "tomato", "lime", "cilantro", "salt"],
    "instructions": "Mash avocado. Mix chopped ingredients.",
    "tags": ["dip", "healthy", "snack"],
  },
  {
    "name": "Greek Salad",
    "ingredients": [
      "tomato",
      "cucumber",
      "olive oil",
      "onion",
      "feta",
      "oregano",
    ],
    "instructions": "Chop and mix all ingredients.",
    "tags": ["veggie", "fresh", "low-cal"],
  },
  {
    "name": "Fruit Yogurt Bowl",
    "ingredients": ["yogurt", "banana", "berries", "honey", "granola"],
    "instructions": "Layer yogurt, fruit and granola.",
    "tags": ["breakfast", "healthy"],
  },
  {
    "name": "Stir-Fry Veggies",
    "ingredients": ["broccoli", "carrot", "pepper", "soy sauce", "garlic"],
    "instructions": "Stir fry on high heat.",
    "tags": ["vegan", "fast"],
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
    });
  }
  scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
  return scored.take(topK).toList();
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

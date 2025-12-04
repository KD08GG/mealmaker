import '../models/recipe.dart';

final List<Recipe> initialRecipes = [
  Recipe(
    name: "Avocado Toast Deluxe",
    ingredients: ["bread", "avocado", "salt", "pepper", "lime"],
    instructions: "Toast bread. Mash avocado with lime, salt, pepper. Spread and serve.",
  ),
  Recipe(
    name: "Garlic Butter Pasta",
    ingredients: ["pasta", "garlic", "butter", "salt", "parsley"],
    instructions: "Cook pasta. Melt butter with garlic. Mix with pasta and top with parsley.",
  ),
  Recipe(
    name: "Chicken Veggie Bowl",
    ingredients: ["chicken", "rice", "carrot", "broccoli", "soy sauce"],
    instructions: "Cook chicken. Steam veggies. Serve over rice with soy sauce.",
  ),
  Recipe(
    name: "Greek Yogurt Parfait",
    ingredients: ["yogurt", "granola", "honey", "berries", "banana"],
    instructions: "Layer yogurt, granola, and fruit. Drizzle honey on top.",
  ),
  Recipe(
    name: "Veggie Stir Fry",
    ingredients: ["broccoli", "carrot", "pepper", "onion", "soy sauce", "garlic"],
    instructions: "Heat oil, add garlic and veggies. Stir fry with soy sauce until tender.",
  ),
  Recipe(
    name: "Tuna Salad Sandwich",
    ingredients: ["tuna", "bread", "mayo", "lettuce", "tomato", "onion"],
    instructions: "Mix tuna with mayo. Layer on bread with veggies.",
  ),
  Recipe(
    name: "Scrambled Eggs with Toast",
    ingredients: ["eggs", "butter", "bread", "salt", "pepper"],
    instructions: "Whisk eggs. Scramble in butter. Serve with toasted bread.",
  ),
  Recipe(
    name: "Caprese Salad",
    ingredients: ["tomato", "mozzarella", "basil", "olive oil", "salt"],
    instructions: "Slice tomato and mozzarella. Layer with basil. Drizzle oil and salt.",
  ),
  Recipe(
    name: "Beef Tacos",
    ingredients: ["beef", "tortillas", "lettuce", "cheese", "tomato", "sour cream"],
    instructions: "Brown beef with spices. Fill tortillas with beef and toppings.",
  ),
  Recipe(
    name: "Smoothie Bowl",
    ingredients: ["banana", "berries", "yogurt", "granola", "honey"],
    instructions: "Blend banana, berries, and yogurt. Top with granola and honey.",
  ),
  Recipe(
    name: "Mushroom Risotto",
    ingredients: ["rice", "mushroom", "onion", "garlic", "butter", "parmesan"],
    instructions: "Sauté mushrooms. Cook rice slowly adding broth. Stir in butter and cheese.",
  ),
  Recipe(
    name: "Caesar Salad",
    ingredients: ["lettuce", "croutons", "parmesan", "caesar dressing", "lemon"],
    instructions: "Toss lettuce with dressing. Add croutons, parmesan, and lemon juice.",
  ),
  Recipe(
    name: "Baked Salmon",
    ingredients: ["salmon", "lemon", "garlic", "olive oil", "dill", "salt"],
    instructions: "Season salmon with oil, garlic, lemon. Bake at 375°F for 15 minutes.",
  ),
  Recipe(
    name: "Vegetable Soup",
    ingredients: ["carrot", "celery", "onion", "tomato", "potato", "broth"],
    instructions: "Chop veggies. Simmer in broth for 30 minutes until tender.",
  ),
  Recipe(
    name: "Pancakes",
    ingredients: ["flour", "milk", "eggs", "sugar", "butter", "baking powder"],
    instructions: "Mix ingredients. Pour batter on griddle. Flip when bubbles form.",
  ),
  Recipe(
    name: "Grilled Cheese Sandwich",
    ingredients: ["bread", "cheese", "butter"],
    instructions: "Butter bread. Add cheese between slices. Grill until golden.",
  ),
  Recipe(
    name: "Chicken Quesadilla",
    ingredients: ["chicken", "tortilla", "cheese", "pepper", "onion"],
    instructions: "Cook chicken with veggies. Fill tortilla with mixture and cheese. Grill.",
  ),
  Recipe(
    name: "Tomato Basil Pasta",
    ingredients: ["pasta", "tomato", "basil", "garlic", "olive oil", "parmesan"],
    instructions: "Cook pasta. Sauté garlic and tomatoes. Toss with pasta and basil.",
  ),
  Recipe(
    name: "Breakfast Burrito",
    ingredients: ["eggs", "tortilla", "cheese", "beans", "salsa", "avocado"],
    instructions: "Scramble eggs. Fill tortilla with eggs, beans, cheese. Add salsa.",
  ),
  Recipe(
    name: "Chicken Noodle Soup",
    ingredients: ["chicken", "noodles", "carrot", "celery", "onion", "broth"],
    instructions: "Simmer chicken in broth. Add veggies and noodles. Cook until tender.",
  ),
  Recipe(
    name: "Margherita Pizza",
    ingredients: ["pizza dough", "tomato sauce", "mozzarella", "basil", "olive oil"],
    instructions: "Spread sauce on dough. Top with cheese and basil. Bake at 450°F.",
  ),
  Recipe(
    name: "Shrimp Scampi",
    ingredients: ["shrimp", "garlic", "butter", "lemon", "parsley", "pasta"],
    instructions: "Sauté shrimp in garlic butter. Add lemon and parsley. Serve over pasta.",
  ),
  Recipe(
    name: "Chicken Fried Rice",
    ingredients: ["rice", "chicken", "eggs", "peas", "carrot", "soy sauce"],
    instructions: "Stir fry chicken. Add rice, veggies, and scrambled eggs. Season with soy sauce.",
  ),
  Recipe(
    name: "BBQ Chicken Wings",
    ingredients: ["chicken wings", "bbq sauce", "garlic powder", "salt", "pepper"],
    instructions: "Season wings. Bake at 400°F for 40 minutes. Toss in BBQ sauce.",
  ),
  Recipe(
    name: "Beef Stir Fry",
    ingredients: ["beef", "broccoli", "carrot", "onion", "soy sauce", "ginger"],
    instructions: "Slice beef. Stir fry with veggies and ginger. Add soy sauce.",
  ),
  Recipe(
    name: "French Toast",
    ingredients: ["bread", "eggs", "milk", "cinnamon", "sugar", "butter"],
    instructions: "Whisk eggs with milk and cinnamon. Dip bread. Fry in butter.",
  ),
  Recipe(
    name: "Chicken Caesar Wrap",
    ingredients: ["chicken", "tortilla", "lettuce", "parmesan", "caesar dressing"],
    instructions: "Grill chicken. Fill tortilla with lettuce, chicken, cheese. Drizzle dressing.",
  ),
  Recipe(
    name: "Spaghetti Carbonara",
    ingredients: ["spaghetti", "bacon", "eggs", "parmesan", "pepper", "garlic"],
    instructions: "Cook pasta. Fry bacon. Mix eggs and cheese. Toss hot pasta with mixture.",
  ),
  Recipe(
    name: "Veggie Omelette",
    ingredients: ["eggs", "pepper", "onion", "mushroom", "cheese", "salt"],
    instructions: "Whisk eggs. Pour in pan. Add veggies and cheese. Fold and serve.",
  ),
  Recipe(
    name: "Fish Tacos",
    ingredients: ["fish", "tortilla", "cabbage", "lime", "sour cream", "cilantro"],
    instructions: "Grill fish. Fill tortillas. Top with cabbage, lime, and cream.",
  ),
  Recipe(
    name: "Beef Burger",
    ingredients: ["beef", "bun", "lettuce", "tomato", "cheese", "onion"],
    instructions: "Form patties. Grill beef. Assemble burger with toppings.",
  ),
  Recipe(
    name: "Chicken Teriyaki",
    ingredients: ["chicken", "teriyaki sauce", "rice", "broccoli", "sesame seeds"],
    instructions: "Cook chicken in teriyaki sauce. Serve over rice with broccoli.",
  ),
  Recipe(
    name: "Mac and Cheese",
    ingredients: ["pasta", "cheese", "milk", "butter", "flour", "salt"],
    instructions: "Cook pasta. Make cheese sauce with milk, butter, flour. Mix together.",
  ),
  Recipe(
    name: "Shrimp Tacos",
    ingredients: ["shrimp", "tortilla", "cabbage", "avocado", "lime", "cilantro"],
    instructions: "Sauté shrimp. Fill tortillas. Top with cabbage and avocado.",
  ),
  Recipe(
    name: "Chicken Alfredo",
    ingredients: ["chicken", "pasta", "cream", "parmesan", "garlic", "butter"],
    instructions: "Cook chicken and pasta. Make alfredo sauce with cream and cheese. Combine.",
  ),
  Recipe(
    name: "Egg Fried Rice",
    ingredients: ["rice", "eggs", "peas", "carrot", "soy sauce", "onion"],
    instructions: "Scramble eggs. Stir fry rice with veggies. Add eggs and soy sauce.",
  ),
  Recipe(
    name: "Pork Chops",
    ingredients: ["pork chops", "garlic", "rosemary", "olive oil", "salt", "pepper"],
    instructions: "Season pork. Sear in oil with garlic and rosemary until cooked.",
  ),
  Recipe(
    name: "Chicken Fajitas",
    ingredients: ["chicken", "pepper", "onion", "tortilla", "lime", "cilantro"],
    instructions: "Slice chicken and veggies. Stir fry. Serve in tortillas with lime.",
  ),
  Recipe(
    name: "Minestrone Soup",
    ingredients: ["beans", "pasta", "tomato", "carrot", "celery", "onion"],
    instructions: "Sauté veggies. Add beans, tomatoes, broth. Simmer with pasta.",
  ),
  Recipe(
    name: "Turkey Sandwich",
    ingredients: ["turkey", "bread", "lettuce", "tomato", "mayo", "cheese"],
    instructions: "Layer turkey on bread with veggies and mayo.",
  ),
  Recipe(
    name: "Beef Stroganoff",
    ingredients: ["beef", "mushroom", "onion", "sour cream", "noodles", "butter"],
    instructions: "Brown beef. Sauté mushrooms and onions. Add sour cream. Serve over noodles.",
  ),
  Recipe(
    name: "Chicken Parmesan",
    ingredients: ["chicken", "tomato sauce", "mozzarella", "parmesan", "pasta", "basil"],
    instructions: "Bread and fry chicken. Top with sauce and cheese. Bake. Serve over pasta.",
  ),
  Recipe(
    name: "Vegetable Curry",
    ingredients: ["potato", "carrot", "peas", "curry powder", "coconut milk", "onion"],
    instructions: "Sauté onion. Add veggies and curry powder. Simmer in coconut milk.",
  ),
  Recipe(
    name: "BLT Sandwich",
    ingredients: ["bacon", "lettuce", "tomato", "bread", "mayo"],
    instructions: "Fry bacon. Layer on toasted bread with lettuce, tomato, and mayo.",
  ),
  Recipe(
    name: "Chicken Salad",
    ingredients: ["chicken", "lettuce", "tomato", "cucumber", "ranch dressing", "croutons"],
    instructions: "Grill chicken. Toss lettuce and veggies. Top with chicken and dressing.",
  ),
  Recipe(
    name: "Beef Chili",
    ingredients: ["beef", "beans", "tomato", "onion", "chili powder", "garlic"],
    instructions: "Brown beef. Add beans, tomatoes, spices. Simmer for 30 minutes.",
  ),
  Recipe(
    name: "Pad Thai",
    ingredients: ["noodles", "shrimp", "eggs", "peanuts", "lime", "soy sauce"],
    instructions: "Cook noodles. Stir fry shrimp and eggs. Toss with noodles and sauce.",
  ),
  Recipe(
    name: "Chicken Enchiladas",
    ingredients: ["chicken", "tortilla", "cheese", "enchilada sauce", "onion", "sour cream"],
    instructions: "Fill tortillas with chicken and cheese. Cover with sauce. Bake at 350°F.",
  ),
  Recipe(
    name: "Meatball Sub",
    ingredients: ["meatballs", "bread", "tomato sauce", "mozzarella", "parmesan"],
    instructions: "Cook meatballs in sauce. Place in bread. Top with cheese and broil.",
  ),
  Recipe(
    name: "Lemon Herb Chicken",
    ingredients: ["chicken", "lemon", "thyme", "garlic", "olive oil", "salt"],
    instructions: "Marinate chicken in lemon and herbs. Grill or bake until cooked.",
  ),
];

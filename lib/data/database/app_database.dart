import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'recipes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE recipes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          ingredients TEXT,
          instructions TEXT,
          sourceId TEXT
        )
        ''');
      },
    );
  }
}

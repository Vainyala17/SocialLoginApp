import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'user_model.dart';

class DBHelper {
  static Database? _db;
  static const String _tableName = 'User';
  static const int _dbVersion = 2; // Increment version to recreate table

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  static Future<Database> initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'user.db');

    return await openDatabase(
      path,
      version: _dbVersion, // Use version constant
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            photo TEXT,
            loginType TEXT NOT NULL,
            dob TEXT,
            gender TEXT,
            phone TEXT
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Drop and recreate table to fix schema issues
        await db.execute('DROP TABLE IF EXISTS $_tableName');
        await db.execute('''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            photo TEXT,
            loginType TEXT NOT NULL,
            dob TEXT,
            gender TEXT,
            phone TEXT
          )
        ''');
      },
    );
  }

  static Future<bool> insertUser(UserModel user) async {
    try {
      final dbClient = await db;
      await dbClient.insert(
        _tableName,
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('User inserted successfully: ${user.name}');
      return true;
    } catch (e) {
      print('Error inserting user: $e');
      return false;
    }
  }

  static Future<UserModel?> getUser() async {
    try {
      final dbClient = await db;
      final List<Map<String, dynamic>> maps = await dbClient.query(_tableName);

      if (maps.isNotEmpty) {
        print('User found in database: ${maps.first['name']}');
        return UserModel.fromMap(maps.first);
      }
      print('No user found in database');
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  static Future<bool> logout() async {
    try {
      final dbClient = await db;
      await dbClient.delete(_tableName);
      print('User logged out successfully');
      return true;
    } catch (e) {
      print('Error during logout: $e');
      return false;
    }
  }

  static Future<bool> isUserLoggedIn() async {
    final user = await getUser();
    return user != null;
  }

  // Helper method to clear database (for debugging)
  static Future<void> clearDatabase() async {
    try {
      final dbClient = await db;
      await dbClient.delete(_tableName);
      print('Database cleared');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }
}
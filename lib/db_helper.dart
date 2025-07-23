import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'user_model.dart';

class DBHelper {
  static Database? _db;
  static const String _tableName = 'User';

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
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $_tableName(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            photo TEXT,
            loginType TEXT NOT NULL
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
        return UserModel.fromMap(maps.first);
      }
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
}

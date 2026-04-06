import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/application_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = join(databasesPath, 'smart_application_intelligence.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Applications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            deadline TEXT NOT NULL,
            status TEXT NOT NULL,
            fit_score REAL NOT NULL,
            risk_level TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertApplication(ApplicationModel application) async {
    final db = await database;
    return db.insert('Applications', application.toMap());
  }

  Future<List<ApplicationModel>> fetchApplications() async {
    final db = await database;
    final result = await db.query('Applications', orderBy: 'deadline ASC');
    return result.map(ApplicationModel.fromMap).toList();
  }

  Future<int> deleteApplication(int id) async {
    final db = await database;
    return db.delete('Applications', where: 'id = ?', whereArgs: [id]);
  }
}

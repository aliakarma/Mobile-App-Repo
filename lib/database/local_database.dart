import 'dart:io' show Platform;

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/application_model.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  static bool _ffiInitialized = false;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final dbPath = join(
      supportDirectory.path,
      'smart_application_intelligence.db',
    );

    if (_isDesktop) {
      _ensureFfiInitialized();
      return databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    }

    return openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE Applications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        deadline TEXT NOT NULL,
        status TEXT NOT NULL,
        fit_score REAL NOT NULL,
        risk_level TEXT NOT NULL,
        recommendation TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE Applications ADD COLUMN recommendation TEXT NOT NULL DEFAULT 'Prepare More'",
      );
    }
  }

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  void _ensureFfiInitialized() {
    if (_ffiInitialized) {
      return;
    }
    sqfliteFfiInit();
    _ffiInitialized = true;
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

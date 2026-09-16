import 'dart:async';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Central SQLite access point. One instance is shared by the app; tests may
/// construct separate instances backed by an in-memory database.
class AppDatabase {
  AppDatabase({this.pathOverride});

  final String? pathOverride;

  static const int schemaVersion = 1;
  static const String _fileName = 'vlog.db';

  Database? _db;

  static bool _initialized = false;

  /// Must be called once on desktop platforms before any database access.
  static void initFfi() {
    if (_initialized) return;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initialized = true;
  }

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = pathOverride ?? await _defaultPath();
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return db;
  }

  Future<String> _defaultPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, _fileName);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE vehicles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        registration_number TEXT NOT NULL DEFAULT '',
        make TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        variant TEXT NOT NULL DEFAULT '',
        year INTEGER,
        vin TEXT NOT NULL DEFAULT '',
        engine_number TEXT NOT NULL DEFAULT '',
        fuel_type TEXT NOT NULL DEFAULT '',
        current_odometer REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fuel_records (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer REAL NOT NULL,
        quantity REAL NOT NULL,
        price_per_unit REAL NOT NULL,
        total_cost REAL NOT NULL,
        currency TEXT NOT NULL,
        fuel_type TEXT NOT NULL DEFAULT '',
        station TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_fuel_vehicle_date ON fuel_records (vehicle_id, date)');

    await db.execute('''
      CREATE TABLE records (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        odometer REAL,
        cost REAL,
        currency TEXT NOT NULL DEFAULT '',
        provider TEXT NOT NULL DEFAULT '',
        title TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        details TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_records_vehicle_date ON records (vehicle_id, date)');

    await db.execute('''
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY,
        vehicle_id TEXT NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL DEFAULT 'custom',
        recurrence TEXT NOT NULL DEFAULT '{}',
        due_date TEXT,
        due_odometer REAL,
        last_done_date TEXT,
        last_done_odometer REAL,
        state TEXT NOT NULL DEFAULT 'upcoming',
        enabled INTEGER NOT NULL DEFAULT 1,
        notification_ids TEXT NOT NULL DEFAULT '[]',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (vehicle_id) REFERENCES vehicles (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations will be added as the schema evolves.
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

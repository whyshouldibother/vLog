import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._database);

  final AppDatabase _database;
  static const _table = 'app_settings';
  static const _key = 'settings';

  Future<AppSettings> get() async {
    final db = await _database.database;
    final rows = await db.query(_table, where: 'key = ?', whereArgs: [_key], limit: 1);
    if (rows.isEmpty) return const AppSettings();
    final raw = rows.first['value'] as String?;
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final db = await _database.database;
    await db.insert(
      _table,
      {'key': _key, 'value': jsonEncode(settings.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

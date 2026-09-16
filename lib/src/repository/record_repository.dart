import '../database/app_database.dart';
import '../models/record.dart';

class RecordRepository {
  RecordRepository(this._database);

  final AppDatabase _database;

  Future<List<Record>> getByVehicle(String vehicleId) async {
    final db = await _database.database;
    final rows = await db.query('records',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'date DESC, created_at DESC');
    return rows.map(recordFromDbMap).toList();
  }

  Future<List<Record>> getByVehicleAndType(
      String vehicleId, RecordType type) async {
    final db = await _database.database;
    final rows = await db.query('records',
        where: 'vehicle_id = ? AND type = ?',
        whereArgs: [vehicleId, type.name],
        orderBy: 'date DESC');
    return rows.map(recordFromDbMap).toList();
  }

  Future<Record> getById(String id) async {
    final db = await _database.database;
    final rows = await db
        .query('records', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Record $id not found');
    return recordFromDbMap(rows.first);
  }

  Future<Record> create(Record record) async {
    final db = await _database.database;
    await db.insert('records', record.toDbMap());
    return record;
  }

  Future<Record> update(Record record) async {
    final db = await _database.database;
    final updated = record.copyWith(updatedAt: DateTime.now());
    await db.update('records', updated.toDbMap(),
        where: 'id = ?', whereArgs: [updated.id]);
    return updated;
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}
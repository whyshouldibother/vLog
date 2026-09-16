import '../database/app_database.dart';
import '../models/fuel_record.dart';

class FuelRepository {
  FuelRepository(this._database);

  final AppDatabase _database;

  Future<List<FuelRecord>> getByVehicle(String vehicleId) async {
    final db = await _database.database;
    final rows = await db.query('fuel_records',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'date DESC, created_at DESC');
    return rows.map(fuelRecordFromDbMap).toList();
  }

  Future<FuelRecord> getById(String id) async {
    final db = await _database.database;
    final rows = await db
        .query('fuel_records', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Fuel record $id not found');
    return fuelRecordFromDbMap(rows.first);
  }

  Future<FuelRecord> create(FuelRecord record) async {
    final db = await _database.database;
    await db.insert('fuel_records', record.toDbMap());
    await _maybeUpdateVehicleOdometer(record.vehicleId, record.odometer);
    return record;
  }

  Future<FuelRecord> update(FuelRecord record) async {
    final db = await _database.database;
    final updated = record.copyWith(updatedAt: DateTime.now());
    await db.update('fuel_records', updated.toDbMap(),
        where: 'id = ?', whereArgs: [updated.id]);
    await _maybeUpdateVehicleOdometer(updated.vehicleId, updated.odometer);
    return updated;
  }

  // Create without updating vehicle odometer (used for backup import)
  Future<FuelRecord> createWithoutOdometerUpdate(FuelRecord record) async {
    final db = await _database.database;
    await db.insert('fuel_records', record.toDbMap());
    return record;
  }

  // Update without updating vehicle odometer (used for backup import)
  Future<FuelRecord> updateWithoutOdometerUpdate(FuelRecord record) async {
    final db = await _database.database;
    final updated = record.copyWith(updatedAt: DateTime.now());
    await db.update('fuel_records', updated.toDbMap(),
        where: 'id = ?', whereArgs: [updated.id]);
    return updated;
  }

  Future<void> _maybeUpdateVehicleOdometer(String vehicleId, double odometer) async {
    final db = await _database.database;
    final vehicleRow = await db.query('vehicles',
        where: 'id = ?', whereArgs: [vehicleId], limit: 1);
    if (vehicleRow.isEmpty) return;
    final currentOdo = vehicleRow.first['current_odometer'] as double? ?? 0;
    if (odometer > currentOdo) {
      await db.update('vehicles',
          {'current_odometer': odometer, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [vehicleId]);
    }
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('fuel_records', where: 'id = ?', whereArgs: [id]);
  }
}
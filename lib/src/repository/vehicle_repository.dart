import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/vehicle.dart';

class VehicleRepository {
  VehicleRepository(this._database);

  final AppDatabase _database;
  static const _table = 'vehicles';

  Future<List<Vehicle>> getAll() async {
    final db = await _database.database;
    final rows = await db.query(_table, orderBy: 'name COLLATE NOCASE, created_at');
    return rows.map(_fromMap).toList();
  }

  Future<Vehicle?> getById(String id) async {
    final db = await _database.database;
    final rows = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _fromMap(rows.first);
  }

  Future<Vehicle> create(Vehicle vehicle) async {
    final db = await _database.database;
    await db.insert(_table, _toMap(vehicle));
    return vehicle;
  }

  Future<Vehicle> update(Vehicle vehicle) async {
    final db = await _database.database;
    final updated = vehicle.copyWith(updatedAt: DateTime.now());
    await db.update(_table, _toMap(updated), where: 'id = ?', whereArgs: [updated.id]);
    return updated;
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Vehicle> updateOdometer(String id, double odometer) async {
    final vehicle = await getById(id);
    if (vehicle == null) throw StateError('Vehicle $id not found');
    return update(vehicle.copyWith(currentOdometer: odometer));
  }

  static String newId() => const Uuid().v4();

  static Map<String, Object?> _toMap(Vehicle v) => {
        'id': v.id,
        'name': v.name,
        'registration_number': v.registrationNumber,
        'make': v.make,
        'model': v.model,
        'variant': v.variant,
        'year': v.year,
        'vin': v.vin,
        'engine_number': v.engineNumber,
        'fuel_type': v.fuelType,
        'current_odometer': v.currentOdometer,
        'notes': v.notes,
        'created_at': v.createdAt.toIso8601String(),
        'updated_at': v.updatedAt.toIso8601String(),
      };

  static Vehicle _fromMap(Map<String, Object?> map) => Vehicle(
        id: map['id'] as String,
        name: (map['name'] as String?) ?? '',
        registrationNumber: (map['registration_number'] as String?) ?? '',
        make: (map['make'] as String?) ?? '',
        model: (map['model'] as String?) ?? '',
        variant: (map['variant'] as String?) ?? '',
        year: map['year'] as int?,
        vin: (map['vin'] as String?) ?? '',
        engineNumber: (map['engine_number'] as String?) ?? '',
        fuelType: (map['fuel_type'] as String?) ?? '',
        currentOdometer: (map['current_odometer'] as num?)?.toDouble() ?? 0,
        notes: (map['notes'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );
}

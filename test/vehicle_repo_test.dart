import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vlog/src/database/app_database.dart';
import 'package:vlog/src/models/vehicle.dart';
import 'package:vlog/src/repository/vehicle_repository.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase(pathOverride: inMemoryDatabasePath);
    repo = VehicleRepository(database);
    await database.database;
  });

  tearDown(() async {
    await database.close();
  });

  group('VehicleRepository', () {
    test('create and retrieve vehicle', () async {
      final vehicle = Vehicle(
        id: VehicleRepository.newId(),
        name: 'My Car',
        registrationNumber: 'ABC-123',
        make: 'Toyota',
        model: 'Corolla',
        currentOdometer: 50000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.create(vehicle);
      final list = await repo.getAll();
      expect(list.length, 1);
      expect(list.first.name, 'My Car');
      expect(list.first.make, 'Toyota');
      expect(list.first.currentOdometer, 50000);
    });

    test('delete vehicle', () async {
      final v = Vehicle(
        id: VehicleRepository.newId(),
        name: 'X',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.create(v);
      expect(await repo.getAll(), hasLength(1));
      await repo.delete(v.id);
      expect(await repo.getAll(), isEmpty);
    });

    test('update vehicle', () async {
      final v = Vehicle(
        id: VehicleRepository.newId(),
        name: 'Old',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.create(v);
      final updated = v.copyWith(name: 'New');
      await repo.update(updated);
      final fetched = await repo.getById(v.id);
      expect(fetched?.name, 'New');
    });

    test('multiple vehicles', () async {
      for (final name in ['Alpha', 'Beta', 'Gamma']) {
        await repo.create(Vehicle(
          id: VehicleRepository.newId(),
          name: name,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      expect(await repo.getAll(), hasLength(3));
    });
  });
}
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vlog/src/database/app_database.dart';
import 'package:vlog/src/models/fuel_record.dart';
import 'package:vlog/src/models/record.dart';
import 'package:vlog/src/models/vehicle.dart';
import 'package:vlog/src/repository/fuel_repository.dart';
import 'package:vlog/src/repository/record_repository.dart';
import 'package:vlog/src/repository/vehicle_repository.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository vehicles;
  late FuelRepository fuels;
  late RecordRepository records;
  late String vehicleId;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase(pathOverride: inMemoryDatabasePath);
    await database.database;
    vehicles = VehicleRepository(database);
    fuels = FuelRepository(database);
    records = RecordRepository(database);
    vehicleId = VehicleRepository.newId();
    await vehicles.create(Vehicle(
      id: vehicleId,
      name: 'Car',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  });

  tearDown(() async {
    await database.close();
  });

  group('FuelRepository', () {
    test('create and list by vehicle ordered by date desc', () async {
      final early = FuelRecord(
        id: VehicleRepository.newId(),
        vehicleId: vehicleId,
        date: DateTime(2026, 1, 1),
        odometer: 10000,
        quantity: 20,
        pricePerUnit: 150.5,
        totalCost: 3010,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final late_ = FuelRecord(
        id: VehicleRepository.newId(),
        vehicleId: vehicleId,
        date: DateTime(2026, 2, 1),
        odometer: 10500,
        quantity: 30,
        pricePerUnit: 160,
        totalCost: 4800,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fuels.create(early);
      await fuels.create(late_);

      final list = await fuels.getByVehicle(vehicleId);
      expect(list, hasLength(2));
      expect(list.first.odometer, 10500);
      expect(list.last.odometer, 10000);
    });

    test('update and delete', () async {
      final f = FuelRecord(
        id: VehicleRepository.newId(),
        vehicleId: vehicleId,
        date: DateTime(2026, 1, 1),
        odometer: 10000,
        quantity: 20,
        pricePerUnit: 150,
        totalCost: 3000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await fuels.create(f);
      await fuels.update(f.copyWith(quantity: 25, totalCost: 3750));
      final updated = await fuels.getById(f.id);
      expect(updated.quantity, 25);
      expect(updated.totalCost, 3750);

      await fuels.delete(f.id);
      expect(await fuels.getByVehicle(vehicleId), isEmpty);
    });

    test('records are isolated per vehicle', () async {
      final other = VehicleRepository.newId();
      await vehicles.create(Vehicle(
        id: other,
        name: 'Other',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await fuels.create(FuelRecord(
        id: VehicleRepository.newId(),
        vehicleId: other,
        date: DateTime(2026, 1, 1),
        odometer: 1,
        quantity: 1,
        pricePerUnit: 1,
        totalCost: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      expect(await fuels.getByVehicle(vehicleId), isEmpty);
    });
  });

  group('RecordRepository', () {
    test('create and list by vehicle', () async {
      final r = Record(
        id: VehicleRepository.newId(),
        vehicleId: vehicleId,
        type: RecordType.oilChange,
        date: DateTime(2026, 3, 1),
        odometer: 5000,
        cost: 2500,
        title: 'Oil service',
        details: {'oilGrade': '5W-30', 'oilQuantity': 4.0},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await records.create(r);
      final list = await records.getByVehicle(vehicleId);
      expect(list, hasLength(1));
      expect(list.first.type, RecordType.oilChange);
      expect(list.first.details['oilGrade'], '5W-30');
    });

    test('filter by type', () async {
      for (final type in [RecordType.battery, RecordType.insurance]) {
        await records.create(Record(
          id: VehicleRepository.newId(),
          vehicleId: vehicleId,
          type: type,
          date: DateTime(2026, 1, 1),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      final batteries = await records.getByVehicleAndType(
          vehicleId, RecordType.battery);
      expect(batteries, hasLength(1));
      expect(batteries.first.type, RecordType.battery);
    });

    test('deleting a vehicle cascades to its records', () async {
      await records.create(Record(
        id: VehicleRepository.newId(),
        vehicleId: vehicleId,
        type: RecordType.customEvent,
        date: DateTime(2026, 1, 1),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await vehicles.delete(vehicleId);
      expect(await records.getByVehicle(vehicleId), isEmpty);
    });
  });
}
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vlog/src/database/app_database.dart';
import 'package:vlog/src/models/fuel_record.dart';
import 'package:vlog/src/models/record.dart';
import 'package:vlog/src/models/reminder.dart';
import 'package:vlog/src/models/vehicle.dart';
import 'package:vlog/src/models/app_settings.dart';
import 'package:vlog/src/repository/fuel_repository.dart';
import 'package:vlog/src/repository/record_repository.dart';
import 'package:vlog/src/repository/reminder_repository.dart';
import 'package:vlog/src/repository/settings_repository.dart';
import 'package:vlog/src/repository/vehicle_repository.dart';
import 'package:vlog/src/services/backup.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository vehicleRepo;
  late FuelRepository fuelRepo;
  late RecordRepository recordRepo;
  late ReminderRepository reminderRepo;
  late SettingsRepository settingsRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase(pathOverride: inMemoryDatabasePath);
    await database.database;
    vehicleRepo = VehicleRepository(database);
    fuelRepo = FuelRepository(database);
    recordRepo = RecordRepository(database);
    reminderRepo = ReminderRepository(database);
    settingsRepo = SettingsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('BackupExport', () {
    test('encodes all data to JSON with schema version', () {
      final vehicles = [
        Vehicle(
          id: 'v1', name: 'Car', registrationNumber: '',
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final fuels = [
        FuelRecord(
          id: 'f1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
          odometer: 10000, quantity: 40, pricePerUnit: 150, totalCost: 6000,
          currency: 'NPR', fuelType: '', station: '', notes: '',
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final records = [
        Record(
          id: 'r1', vehicleId: 'v1', type: RecordType.oilChange,
          date: DateTime(2026, 1, 1), createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final reminders = [
        Reminder(
          id: 'rem1', vehicleId: 'v1', title: 'Test',
          recurrence: const RecurrenceRule(),
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final settings = AppSettings();

      final json = BackupExport.toJson(
        vehicles: vehicles,
        fuelRecords: fuels,
        records: records,
        reminders: reminders,
        settings: settings,
      );

      expect(json['schemaVersion'], equals(1));
      expect(json['vehicles'], isA<List>());
      expect(json['fuelRecords'], isA<List>());
      expect(json['records'], isA<List>());
      expect(json['reminders'], isA<List>());
      expect(json['settings'], isA<Map>());
      expect(json['exportedAt'], isA<String>());
    });

    test('encode produces valid JSON string', () {
      final vehicles = [
        Vehicle(
          id: 'v1', name: 'Car', registrationNumber: '',
          createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final jsonString = BackupExport.encode(
        vehicles: vehicles,
        fuelRecords: [],
        records: [],
        reminders: [],
        settings: AppSettings(),
      );
      expect(jsonString, contains('"schemaVersion": 1'));
      expect(jsonString, contains('"v1"'));
    });
  });

  group('BackupImport', () {
    test('rejects invalid JSON', () async {
      final result = await BackupImport.importFromJson(
        'not valid json',
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Invalid JSON'));
    });

    test('rejects missing schema version', () async {
      final json = '{"vehicles":[]}';
      final result = await BackupImport.importFromJson(
        json,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Missing schema version'));
    });

    test('rejects unsupported schema version', () async {
      final json = '{"schemaVersion":999,"vehicles":[],"fuelRecords":[],"records":[],"reminders":[],"settings":{}}';
      final result = await BackupImport.importFromJson(
        json,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('Unsupported schema version'));
    });

    test('rejects foreign key violation (unknown vehicle)', () async {
      final json = jsonEncode({
        'schemaVersion': 1,
        'vehicles': [],
        'fuelRecords': [
          {
            'id': 'f1', 'vehicleId': 'unknown', 'date': '2026-01-01T00:00:00.000Z',
            'odometer': 10000, 'quantity': 40, 'pricePerUnit': 150, 'totalCost': 6000,
            'currency': 'NPR', 'fuelType': '', 'station': '', 'notes': '',
            'createdAt': '2026-01-01T00:00:00.000Z', 'updatedAt': '2026-01-01T00:00:00.000Z',
          },
        ],
        'records': [],
        'reminders': [],
        'settings': {
          'themeMode': 'system', 'currency': 'NPR', 'distanceUnit': 'km',
          'volumeUnit': 'liter', 'fuelEconomyUnit': 'kmPerLiter', 'dateFormat': 'dd/MM/yyyy',
        },
      });
      final result = await BackupImport.importFromJson(
        json,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );
      expect(result.success, isFalse);
      expect(result.error, contains('unknown vehicle'));
    });

    test('merge strategy creates new vehicles', () async {
      final vehicle = Vehicle(
        id: 'v1', name: 'Car', registrationNumber: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      final json = jsonEncode({
        'schemaVersion': 1,
        'vehicles': [vehicle.toJson()],
        'fuelRecords': [],
        'records': [],
        'reminders': [],
        'settings': {
          'themeMode': 'system', 'currency': 'NPR', 'distanceUnit': 'km',
          'volumeUnit': 'liter', 'fuelEconomyUnit': 'kmPerLiter', 'dateFormat': 'dd/MM/yyyy',
        },
      });

      final result = await BackupImport.importFromJson(
        json,
        strategy: BackupImport.mergeStrategyMerge,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );

      expect(result.success, isTrue);
      expect(result.vehiclesCreated, equals(1));
      final all = await vehicleRepo.getAll();
      expect(all.length, equals(1));
      expect(all.first.name, equals('Car'));
    });

    test('merge strategy updates existing vehicles', () async {
      final vehicle = Vehicle(
        id: 'v1', name: 'Old Car', registrationNumber: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      await vehicleRepo.create(vehicle);

      final json = jsonEncode({
        'schemaVersion': 1,
        'vehicles': [
          vehicle.copyWith(name: 'New Car', updatedAt: DateTime(2026, 2, 1)).toJson()
        ],
        'fuelRecords': [],
        'records': [],
        'reminders': [],
        'settings': {
          'themeMode': 'system', 'currency': 'NPR', 'distanceUnit': 'km',
          'volumeUnit': 'liter', 'fuelEconomyUnit': 'kmPerLiter', 'dateFormat': 'dd/MM/yyyy',
        },
      });

      final result = await BackupImport.importFromJson(
        json,
        strategy: BackupImport.mergeStrategyMerge,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );

      expect(result.success, isTrue);
      expect(result.vehiclesUpdated, equals(1));
      final all = await vehicleRepo.getAll();
      expect(all.first.name, equals('New Car'));
    });

    test('replace strategy deletes existing data', () async {
      final vehicle = Vehicle(
        id: 'v1', name: 'Car', registrationNumber: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      await vehicleRepo.create(vehicle);

      final json = jsonEncode({
        'schemaVersion': 1,
        'vehicles': [
          Vehicle(
            id: 'v2', name: 'New Car', registrationNumber: '',
            createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
          ).toJson()
        ],
        'fuelRecords': [],
        'records': [],
        'reminders': [],
        'settings': {
          'themeMode': 'system', 'currency': 'NPR', 'distanceUnit': 'km',
          'volumeUnit': 'liter', 'fuelEconomyUnit': 'kmPerLiter', 'dateFormat': 'dd/MM/yyyy',
        },
      });

      final result = await BackupImport.importFromJson(
        json,
        strategy: BackupImport.mergeStrategyReplace,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );

      expect(result.success, isTrue);
      final all = await vehicleRepo.getAll();
      expect(all.length, equals(1));
      expect(all.first.id, equals('v2'));
    });

    test('imports fuel records, records, reminders, and settings', () async {
      final vehicle = Vehicle(
        id: 'v1', name: 'Car', registrationNumber: '',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      await vehicleRepo.create(vehicle);

      final json = jsonEncode({
        'schemaVersion': 1,
        'vehicles': [vehicle.toJson()],
        'fuelRecords': [
          FuelRecord(
            id: 'f1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
            odometer: 10000, quantity: 40, pricePerUnit: 150, totalCost: 6000,
            currency: 'USD', fuelType: 'Gasoline', station: 'Shell', notes: 'Full tank',
            createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
        'records': [
          Record(
            id: 'r1', vehicleId: 'v1', type: RecordType.oilChange,
            date: DateTime(2026, 1, 1), odometer: 10000, cost: 3000,
            title: 'Oil change', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
        'reminders': [
          Reminder(
            id: 'rem1', vehicleId: 'v1', title: 'Oil due',
            recurrence: const RecurrenceRule(),
            createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
          ).toJson(),
        ],
        'settings': {
          'themeMode': 'dark', 'currency': 'EUR', 'distanceUnit': 'mile',
          'volumeUnit': 'gallonUs', 'fuelEconomyUnit': 'mpg', 'dateFormat': 'MM/dd/yyyy',
        },
      });

      final result = await BackupImport.importFromJson(
        json,
        strategy: BackupImport.mergeStrategyMerge,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );

      expect(result.success, isTrue);
      expect(result.fuelsCreated, equals(1));
      expect(result.recordsCreated, equals(1));
      expect(result.remindersCreated, equals(1));
      expect(result.settingsImported, isTrue);

      final settings = await settingsRepo.get();
      expect(settings.currency, equals('EUR'));
      expect(settings.themeMode, equals(AppThemeMode.dark));
    });

    test('round-trip export/import preserves data', () async {
      // Create test data
      final vehicle = Vehicle(
        id: 'v1', name: 'Test Car', registrationNumber: 'ABC123',
        make: 'Toyota', model: 'Corolla', variant: 'LE', year: 2020,
        vin: 'VIN123', engineNumber: 'ENG456', fuelType: 'Gasoline',
        currentOdometer: 50000, notes: 'Test vehicle',
        createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
      );
      await vehicleRepo.create(vehicle);

      final fuel = FuelRecord(
        id: 'f1', vehicleId: 'v1', date: DateTime(2026, 1, 15),
        odometer: 50500, quantity: 45.5, pricePerUnit: 155.25, totalCost: 7064.625,
        currency: 'NPR', fuelType: 'Gasoline', station: 'Station A', notes: 'Fill up',
        createdAt: DateTime(2026, 1, 15), updatedAt: DateTime(2026, 1, 15),
      );
      await fuelRepo.create(fuel);

      final record = Record(
        id: 'r1', vehicleId: 'v1', type: RecordType.oilChange,
        date: DateTime(2026, 2, 1), odometer: 51000, cost: 4500,
        title: 'Oil service', details: {'oilGrade': '5W-30', 'oilQuantity': 4.5},
        createdAt: DateTime(2026, 2, 1), updatedAt: DateTime(2026, 2, 1),
      );
      await recordRepo.create(record);

      final reminder = Reminder(
        id: 'rem1', vehicleId: 'v1', title: 'Next oil change',
        description: 'Change oil at 55000 km',
        category: 'maintenance',
        recurrence: RecurrenceRule(type: RecurrenceType.distanceKm, intervalKm: 5000),
        dueOdometer: 55000,
        enabled: true,
        createdAt: DateTime(2026, 2, 1), updatedAt: DateTime(2026, 2, 1),
      );
      await reminderRepo.create(reminder);

      await settingsRepo.save(AppSettings(
        themeMode: AppThemeMode.dark,
        currency: 'USD',
        distanceUnit: DistanceUnit.mile,
        volumeUnit: VolumeUnit.gallonUs,
        fuelEconomyUnit: FuelEconomyUnit.mpg,
        dateFormat: 'yyyy-MM-dd',
      ));

      // Export
      final vehicles = await vehicleRepo.getAll();
      final fuels = await fuelRepo.getByVehicle('v1');
      final records = await recordRepo.getByVehicle('v1');
      final reminders = await reminderRepo.getByVehicle('v1');
      final settings = await settingsRepo.get();

      final jsonString = BackupExport.encode(
        vehicles: vehicles,
        fuelRecords: fuels,
        records: records,
        reminders: reminders,
        settings: settings,
      );

      // Clear all data (simulate fresh import)
      for (final v in await vehicleRepo.getAll()) {
        await vehicleRepo.delete(v.id);
      }

      // Import
      final result = await BackupImport.importFromJson(
        jsonString,
        strategy: BackupImport.mergeStrategyMerge,
        vehicleRepo: vehicleRepo,
        fuelRepo: fuelRepo,
        recordRepo: recordRepo,
        reminderRepo: reminderRepo,
        settingsRepo: settingsRepo,
      );

      expect(result.success, isTrue);

      // Verify all data restored
      final importedVehicles = await vehicleRepo.getAll();
      expect(importedVehicles.length, equals(1));
      expect(importedVehicles.first.name, equals('Test Car'));
      expect(importedVehicles.first.registrationNumber, equals('ABC123'));
      expect(importedVehicles.first.currentOdometer, equals(50500));

      final importedFuels = await fuelRepo.getByVehicle('v1');
      expect(importedFuels.length, equals(1));
      expect(importedFuels.first.quantity, equals(45.5));
      expect(importedFuels.first.currency, equals('NPR'));

      final importedRecords = await recordRepo.getByVehicle('v1');
      expect(importedRecords.length, equals(1));
      expect(importedRecords.first.type, equals(RecordType.oilChange));
      expect(importedRecords.first.cost, equals(4500));

      final importedReminders = await reminderRepo.getByVehicle('v1');
      expect(importedReminders.length, equals(1));
      expect(importedReminders.first.title, equals('Next oil change'));
      expect(importedReminders.first.recurrence.type, equals(RecurrenceType.distanceKm));
      expect(importedReminders.first.dueOdometer, equals(55000));

      final importedSettings = await settingsRepo.get();
      expect(importedSettings.currency, equals('USD'));
      expect(importedSettings.themeMode, equals(AppThemeMode.dark));
      expect(importedSettings.distanceUnit, equals(DistanceUnit.mile));
    });
  });
}
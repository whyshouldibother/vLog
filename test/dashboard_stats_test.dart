import 'package:flutter_test/flutter_test.dart';
import 'package:vlog/src/models/vehicle.dart';
import 'package:vlog/src/models/fuel_record.dart';
import 'package:vlog/src/models/record.dart';
import 'package:vlog/src/models/reminder.dart';
import 'package:vlog/src/models/app_settings.dart';
import 'package:vlog/src/services/dashboard_stats.dart';

void main() {
  group('computeDashboardStats', () {
    late List<Vehicle> vehicles;
    late List<FuelRecord> fuels;
    late List<Record> records;
    late List<Reminder> reminders;
    late AppSettings settings;

    setUp(() {
      vehicles = [
        Vehicle(
          id: 'v1', name: 'Car 1', registrationNumber: 'ABC123',
          createdAt: DateTime.now(), updatedAt: DateTime.now(), currentOdometer: 10000,
        ),
        Vehicle(
          id: 'v2', name: 'Car 2', registrationNumber: 'XYZ789',
          createdAt: DateTime.now(), updatedAt: DateTime.now(), currentOdometer: 20000,
        ),
      ];

      fuels = [
        FuelRecord(
          id: 'f1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
          odometer: 10000, quantity: 40, pricePerUnit: 150, totalCost: 6000,
          currency: 'NPR', fuelType: '', station: '', notes: '',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        FuelRecord(
          id: 'f2', vehicleId: 'v1', date: DateTime(2026, 2, 1),
          odometer: 10500, quantity: 30, pricePerUnit: 160, totalCost: 4800,
          currency: 'NPR', fuelType: '', station: '', notes: '',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        FuelRecord(
          id: 'f3', vehicleId: 'v2', date: DateTime(2026, 1, 15),
          odometer: 20000, quantity: 50, pricePerUnit: 140, totalCost: 7000,
          currency: 'NPR', fuelType: '', station: '', notes: '',
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
      ];

      records = [
        Record(
          id: 'r1', vehicleId: 'v1', type: RecordType.oilChange,
          date: DateTime(2026, 1, 15), odometer: 10200,
          cost: 3000, title: 'Oil change', createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        Record(
          id: 'r2', vehicleId: 'v2', type: RecordType.repair,
          date: DateTime(2026, 2, 1), odometer: 20500,
          cost: 5000, title: 'Brake repair', createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
      ];

      reminders = [
        Reminder(
          id: 'rem1', vehicleId: 'v1', title: 'Oil due',
          recurrence: const RecurrenceRule(), dueDate: DateTime.now().add(const Duration(days: 30)),
          enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        Reminder(
          id: 'rem2', vehicleId: 'v2', title: 'Inspection',
          recurrence: const RecurrenceRule(), dueDate: DateTime.now().subtract(const Duration(days: 1)),
          enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
        Reminder(
          id: 'rem3', vehicleId: 'v1', title: 'Disabled',
          recurrence: const RecurrenceRule(), enabled: false,
          createdAt: DateTime.now(), updatedAt: DateTime.now(),
        ),
      ];

      settings = AppSettings();
    });

    test('computes vehicle count', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      expect(stats.vehicleCount, equals(2));
    });

    test('computes total fuel and service entries', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      expect(stats.totalFuelEntries, equals(3));
      expect(stats.totalServiceEntries, equals(2));
    });

    test('computes total costs', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      expect(stats.totalFuelCost, equals(6000 + 4800 + 7000));
      expect(stats.totalServiceCost, equals(3000 + 5000));
    });

    test('computes total odometer', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      expect(stats.totalOdometer, equals(30000));
    });

    test('computes fuel cost by month', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      expect(stats.fuelCostByMonth['2026-01'], equals(6000 + 7000));
      expect(stats.fuelCostByMonth['2026-02'], equals(4800));
    });

    test('computes upcoming reminders (enabled, not completed)', () {
      final stats = computeDashboardStats(
        vehicles: vehicles, allFuelRecords: fuels, allRecords: records,
        allReminders: reminders, settings: settings,
      );
      // rem1: upcoming, rem2: overdue, rem3: disabled
      expect(stats.upcomingReminders, equals(2));
    });

    test('empty data returns zeros', () {
      final stats = computeDashboardStats(
        vehicles: [], allFuelRecords: [], allRecords: [],
        allReminders: [], settings: settings,
      );
      expect(stats.vehicleCount, equals(0));
      expect(stats.totalFuelEntries, equals(0));
      expect(stats.totalServiceEntries, equals(0));
      expect(stats.totalFuelCost, equals(0));
      expect(stats.totalServiceCost, equals(0));
      expect(stats.averageEconomy, equals(0));
      expect(stats.bestEconomy, equals(0));
      expect(stats.latestEconomy, isNull);
    });
  });
}
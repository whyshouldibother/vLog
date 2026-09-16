import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../models/app_settings.dart';
import '../models/fuel_record.dart';
import '../models/record.dart';
import '../models/reminder.dart';
import '../models/vehicle.dart';
import '../repository/fuel_repository.dart';
import '../repository/record_repository.dart';
import '../repository/reminder_repository.dart';
import '../repository/settings_repository.dart';
import '../repository/vehicle_repository.dart';

part 'providers.g.dart';

@riverpod
AppDatabase appDatabase(Ref ref) => AppDatabase();

@riverpod
VehicleRepository vehicleRepository(Ref ref) =>
    VehicleRepository(ref.watch(appDatabaseProvider));

@riverpod
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

@riverpod
FuelRepository fuelRepository(Ref ref) =>
    FuelRepository(ref.watch(appDatabaseProvider));

@riverpod
RecordRepository recordRepository(Ref ref) =>
    RecordRepository(ref.watch(appDatabaseProvider));

@riverpod
class AppSettingsNotifier extends _$AppSettingsNotifier {
  @override
  Future<AppSettings> build() =>
      ref.watch(settingsRepositoryProvider).get();

  Future<void> updateSettings(AppSettings value) async {
    await ref.read(settingsRepositoryProvider).save(value);
    state = AsyncData(value);
  }
}

@riverpod
Future<bool> hasCompletedOnboarding(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('has_completed_onboarding') ?? false;
}

@riverpod
Future<void> completeOnboarding(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('has_completed_onboarding', true);
}

@riverpod
class VehiclesNotifier extends _$VehiclesNotifier {
  @override
  Future<List<Vehicle>> build() =>
      ref.watch(vehicleRepositoryProvider).getAll();

  Future<Vehicle> addVehicle(Vehicle vehicle) async {
    final created = await ref.read(vehicleRepositoryProvider).create(vehicle);
    ref.invalidateSelf();
    return created;
  }

  Future<Vehicle> updateVehicle(Vehicle vehicle) async {
    final updated = await ref.read(vehicleRepositoryProvider).update(vehicle);
    ref.invalidateSelf();
    return updated;
  }

  Future<void> deleteVehicle(String id) async {
    await ref.read(vehicleRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

@riverpod
Future<List<FuelRecord>> fuelRecords(Ref ref, String vehicleId) async {
  return ref.watch(fuelRepositoryProvider).getByVehicle(vehicleId);
}

@riverpod
Future<List<Record>> vehicleRecords(Ref ref, String vehicleId) async {
  return ref.watch(recordRepositoryProvider).getByVehicle(vehicleId);
}

@riverpod
ReminderRepository reminderRepository(Ref ref) =>
    ReminderRepository(ref.watch(appDatabaseProvider));

@riverpod
Future<List<Reminder>> reminders(Ref ref, String vehicleId) async {
  return ref.watch(reminderRepositoryProvider).getByVehicle(vehicleId);
}

@riverpod
Future<List<String>> fuelTypes(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider).database;
  final rows = await db.rawQuery(
    'SELECT DISTINCT fuel_type FROM fuel_records WHERE fuel_type IS NOT NULL AND fuel_type != \'\' ORDER BY fuel_type',
  );
  return rows.map((r) => r['fuel_type'] as String).toList();
}

@riverpod
Future<List<String>> stations(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider).database;
  final rows = await db.rawQuery(
    'SELECT DISTINCT station FROM fuel_records WHERE station IS NOT NULL AND station != \'\' ORDER BY station',
  );
  return rows.map((r) => r['station'] as String).toList();
}

@riverpod
class RemindersNotifier extends _$RemindersNotifier {
  @override
  Future<List<Reminder>> build(String vehicleId) =>
      ref.watch(reminderRepositoryProvider).getByVehicle(vehicleId);

  Future<Reminder> addReminder(Reminder reminder) async {
    final created = await ref.read(reminderRepositoryProvider).create(reminder);
    ref.invalidateSelf();
    ref.invalidate(remindersProvider(vehicleId));
    return created;
  }

  Future<Reminder> updateReminder(Reminder reminder) async {
    final updated = await ref.read(reminderRepositoryProvider).update(reminder);
    ref.invalidateSelf();
    ref.invalidate(remindersProvider(vehicleId));
    return updated;
  }

  Future<void> deleteReminder(String id) async {
    await ref.read(reminderRepositoryProvider).delete(id);
    ref.invalidateSelf();
    ref.invalidate(remindersProvider(vehicleId));
  }
}

@riverpod
Future<List<FuelRecord>> allFuelRecords(Ref ref) async {
  final vehicles = await ref.watch(vehiclesNotifierProvider.future);
  final repo = ref.watch(fuelRepositoryProvider);
  final all = <FuelRecord>[];
  for (final v in vehicles) {
    all.addAll(await repo.getByVehicle(v.id));
  }
  return all;
}

@riverpod
Future<List<Record>> allRecords(Ref ref) async {
  final vehicles = await ref.watch(vehiclesNotifierProvider.future);
  final repo = ref.watch(recordRepositoryProvider);
  final all = <Record>[];
  for (final v in vehicles) {
    all.addAll(await repo.getByVehicle(v.id));
  }
  return all;
}

@riverpod
Future<List<Reminder>> allReminders(Ref ref) async {
  final vehicles = await ref.watch(vehiclesNotifierProvider.future);
  final repo = ref.watch(reminderRepositoryProvider);
  final all = <Reminder>[];
  for (final v in vehicles) {
    all.addAll(await repo.getByVehicle(v.id));
  }
  return all;
}
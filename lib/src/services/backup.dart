import 'dart:convert';

import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../models/record.dart';
import '../models/reminder.dart';
import '../models/app_settings.dart';
import '../repository/vehicle_repository.dart';
import '../repository/fuel_repository.dart';
import '../repository/record_repository.dart';
import '../repository/reminder_repository.dart';
import '../repository/settings_repository.dart';

const int _backupSchemaVersion = 1;

class BackupExport {
  static const String schemaVersionKey = 'schemaVersion';
  static const String vehiclesKey = 'vehicles';
  static const String fuelRecordsKey = 'fuelRecords';
  static const String recordsKey = 'records';
  static const String remindersKey = 'reminders';
  static const String settingsKey = 'settings';
  static const String exportedAtKey = 'exportedAt';

  static Map<String, dynamic> toJson({
    required List<Vehicle> vehicles,
    required List<FuelRecord> fuelRecords,
    required List<Record> records,
    required List<Reminder> reminders,
    required AppSettings settings,
  }) {
    return {
      schemaVersionKey: _backupSchemaVersion,
      exportedAtKey: DateTime.now().toIso8601String(),
      vehiclesKey: vehicles.map((v) => v.toJson()).toList(),
      fuelRecordsKey: fuelRecords.map((f) => f.toJson()).toList(),
      recordsKey: records.map((r) => r.toJson()).toList(),
      remindersKey: reminders.map((r) => r.toJson()).toList(),
      settingsKey: settings.toJson(),
    };
  }

  static String encode({
    required List<Vehicle> vehicles,
    required List<FuelRecord> fuelRecords,
    required List<Record> records,
    required List<Reminder> reminders,
    required AppSettings settings,
  }) {
    final json = toJson(
      vehicles: vehicles,
      fuelRecords: fuelRecords,
      records: records,
      reminders: reminders,
      settings: settings,
    );
    return const JsonEncoder.withIndent('  ').convert(json);
  }
}

class BackupImport {
  static const String schemaVersionKey = 'schemaVersion';
  static const String vehiclesKey = 'vehicles';
  static const String fuelRecordsKey = 'fuelRecords';
  static const String recordsKey = 'records';
  static const String remindersKey = 'reminders';
  static const String settingsKey = 'settings';

  static const String mergeStrategyReplace = 'replace';
  static const String mergeStrategyMerge = 'merge';

  static Future<BackupImportResult> importFromJson(
    String jsonString, {
    String strategy = mergeStrategyMerge,
    required VehicleRepository vehicleRepo,
    required FuelRepository fuelRepo,
    required RecordRepository recordRepo,
    required ReminderRepository reminderRepo,
    required SettingsRepository settingsRepo,
  }) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return BackupImportResult(
        success: false,
        error: 'Invalid JSON: $e',
      );
    }

    if (!data.containsKey(schemaVersionKey)) {
      return BackupImportResult(
        success: false,
        error: 'Missing schema version',
      );
    }
    final schemaVersion = data[schemaVersionKey] as int;
    if (schemaVersion > _backupSchemaVersion) {
      return BackupImportResult(
        success: false,
        error: 'Unsupported schema version $schemaVersion (current: $_backupSchemaVersion)',
      );
    }

    try {
      // Parse all data
      final vehiclesJson = data[vehiclesKey] as List<dynamic>? ?? [];
      final fuelRecordsJson = data[fuelRecordsKey] as List<dynamic>? ?? [];
      final recordsJson = data[recordsKey] as List<dynamic>? ?? [];
      final remindersJson = data[remindersKey] as List<dynamic>? ?? [];
      final settingsJson = data[settingsKey] as Map<String, dynamic>?;

      final vehicles = vehiclesJson.map((j) => Vehicle.fromJson(j as Map<String, dynamic>)).toList();
      final fuelRecords = fuelRecordsJson.map((j) => FuelRecord.fromJson(j as Map<String, dynamic>)).toList();
      final records = recordsJson.map((j) => Record.fromJson(j as Map<String, dynamic>)).toList();
      final reminders = remindersJson.map((j) => Reminder.fromJson(j as Map<String, dynamic>)).toList();
      final settings = settingsJson != null ? AppSettings.fromJson(settingsJson) : null;

      // Validate foreign keys
      final vehicleIds = vehicles.map((v) => v.id).toSet();
      for (final f in fuelRecords) {
        if (!vehicleIds.contains(f.vehicleId)) {
          return BackupImportResult(
            success: false,
            error: 'Fuel record ${f.id} references unknown vehicle ${f.vehicleId}',
          );
        }
      }
      for (final r in records) {
        if (!vehicleIds.contains(r.vehicleId)) {
          return BackupImportResult(
            success: false,
            error: 'Record ${r.id} references unknown vehicle ${r.vehicleId}',
          );
        }
      }
      for (final r in reminders) {
        if (!vehicleIds.contains(r.vehicleId)) {
          return BackupImportResult(
            success: false,
            error: 'Reminder ${r.id} references unknown vehicle ${r.vehicleId}',
          );
        }
      }

      // Import based on strategy
      if (strategy == mergeStrategyReplace) {
        // Delete all existing data first
        for (final v in await vehicleRepo.getAll()) {
          await vehicleRepo.delete(v.id);
        }
      }

      // Import vehicles
      int vehiclesCreated = 0, vehiclesUpdated = 0;
      for (final v in vehicles) {
        final existing = await _tryGetById(vehicleRepo, v.id);
        if (existing != null) {
          await vehicleRepo.update(v);
          vehiclesUpdated++;
        } else {
          await vehicleRepo.create(v);
          vehiclesCreated++;
        }
      }

      // Import fuel records
      int fuelsCreated = 0, fuelsUpdated = 0;
      for (final f in fuelRecords) {
        final existing = await _tryGetById(fuelRepo, f.id);
        if (existing != null) {
          await fuelRepo.updateWithoutOdometerUpdate(f);
          fuelsUpdated++;
        } else {
          await fuelRepo.createWithoutOdometerUpdate(f);
          fuelsCreated++;
        }
      }

      // Import records
      int recordsCreated = 0, recordsUpdated = 0;
      for (final r in records) {
        final existing = await _tryGetById(recordRepo, r.id);
        if (existing != null) {
          await recordRepo.update(r);
          recordsUpdated++;
        } else {
          await recordRepo.create(r);
          recordsCreated++;
        }
      }

      // Import reminders
      int remindersCreated = 0, remindersUpdated = 0;
      for (final r in reminders) {
        final existing = await _tryGetById(reminderRepo, r.id);
        if (existing != null) {
          await reminderRepo.update(r);
          remindersUpdated++;
        } else {
          await reminderRepo.create(r);
          remindersCreated++;
        }
      }

      // Import settings
      if (settings != null) {
        await settingsRepo.save(settings);
      }

      return BackupImportResult(
        success: true,
        vehiclesCreated: vehiclesCreated,
        vehiclesUpdated: vehiclesUpdated,
        fuelsCreated: fuelsCreated,
        fuelsUpdated: fuelsUpdated,
        recordsCreated: recordsCreated,
        recordsUpdated: recordsUpdated,
        remindersCreated: remindersCreated,
        remindersUpdated: remindersUpdated,
        settingsImported: settings != null,
      );
    } catch (e) {
      return BackupImportResult(
        success: false,
        error: 'Import failed: $e',
      );
    }
  }
}

class BackupImportResult {
  const BackupImportResult({
    required this.success,
    this.error,
    this.vehiclesCreated = 0,
    this.vehiclesUpdated = 0,
    this.fuelsCreated = 0,
    this.fuelsUpdated = 0,
    this.recordsCreated = 0,
    this.recordsUpdated = 0,
    this.remindersCreated = 0,
    this.remindersUpdated = 0,
    this.settingsImported = false,
  });

  final bool success;
  final String? error;
  final int vehiclesCreated;
  final int vehiclesUpdated;
  final int fuelsCreated;
  final int fuelsUpdated;
  final int recordsCreated;
  final int recordsUpdated;
  final int remindersCreated;
  final int remindersUpdated;
  final bool settingsImported;

  String get summary {
    if (!success) return 'Import failed: $error';
    final parts = <String>[
      if (vehiclesCreated > 0 || vehiclesUpdated > 0)
        'Vehicles: ${vehiclesCreated} created, ${vehiclesUpdated} updated',
      if (fuelsCreated > 0 || fuelsUpdated > 0)
        'Fuel records: ${fuelsCreated} created, ${fuelsUpdated} updated',
      if (recordsCreated > 0 || recordsUpdated > 0)
        'Records: ${recordsCreated} created, ${recordsUpdated} updated',
      if (remindersCreated > 0 || remindersUpdated > 0)
        'Reminders: ${remindersCreated} created, ${remindersUpdated} updated',
      if (settingsImported) 'Settings: updated',
    ];
    return parts.isEmpty ? 'No changes' : parts.join('\n');
  }
}

Future<T?> _tryGetById<T>(dynamic repo, String id) async {
  try {
    return await repo.getById(id) as T?;
  } catch (_) {
    return null;
  }
}
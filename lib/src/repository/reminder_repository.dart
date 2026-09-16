import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../models/reminder.dart';

class ReminderRepository {
  ReminderRepository(this._database);

  final AppDatabase _database;

  Future<List<Reminder>> getByVehicle(String vehicleId) async {
    final db = await _database.database;
    final rows = await db.query('reminders',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'due_date ASC, created_at ASC');
    return rows.map(reminderFromDbMap).toList();
  }

  Future<List<Reminder>> getByVehicleAndState(
      String vehicleId, ReminderState state) async {
    final db = await _database.database;
    final rows = await db.query('reminders',
        where: 'vehicle_id = ? AND state = ?',
        whereArgs: [vehicleId, state.name],
        orderBy: 'due_date ASC');
    return rows.map(reminderFromDbMap).toList();
  }

  Future<Reminder> getById(String id) async {
    final db = await _database.database;
    final rows = await db
        .query('reminders', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) throw StateError('Reminder $id not found');
    return reminderFromDbMap(rows.first);
  }

  Future<Reminder> create(Reminder reminder) async {
    final db = await _database.database;
    await db.insert('reminders', reminder.toDbMap());
    return reminder;
  }

  Future<Reminder> update(Reminder reminder) async {
    final db = await _database.database;
    final updated = reminder.copyWith(updatedAt: DateTime.now());
    await db.update('reminders', updated.toDbMap(),
        where: 'id = ?', whereArgs: [updated.id]);
    return updated;
  }

  Future<void> delete(String id) async {
    final db = await _database.database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  static String newId() => const Uuid().v4();
}
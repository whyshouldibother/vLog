import 'package:flutter_test/flutter_test.dart';
import 'package:vlog/src/models/reminder.dart';
import 'package:vlog/src/services/reminder_engine.dart';

void main() {
  group('nextDueDate', () {
    test('daily recurrence', () {
      final rule = RecurrenceRule(type: RecurrenceType.daily, intervalDays: 2);
      final from = DateTime(2026, 1, 1);
      final next = nextDueDate(rule, from);
      expect(next, equals(DateTime(2026, 1, 3)));
    });

    test('daily recurrence respects max occurrences', () {
      final rule = RecurrenceRule(
          type: RecurrenceType.daily, intervalDays: 1, maxOccurrences: 3);
      final from = DateTime(2026, 1, 1);
      expect(nextDueDate(rule, from, occurrences: 2), isNotNull);
      expect(nextDueDate(rule, from, occurrences: 3), isNull);
    });

    test('weekly recurrence on specific weekdays', () {
      final rule = RecurrenceRule(
          type: RecurrenceType.weekly, weekDays: [DateTime.monday, DateTime.wednesday]);
      final from = DateTime(2026, 1, 4); // Sunday
      final next = nextDueDate(rule, from);
      expect(next?.weekday, equals(DateTime.monday));
    });

    test('monthly recurrence on specific day', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly, monthDay: 15);
      final from = DateTime(2026, 1, 1);
      final next = nextDueDate(rule, from);
      expect(next, equals(DateTime(2026, 1, 15)));
    });

    test('yearly recurrence', () {
      final rule = RecurrenceRule(type: RecurrenceType.yearly, yearMonth: 6, yearDay: 15);
      final from = DateTime(2026, 1, 1);
      final next = nextDueDate(rule, from);
      expect(next, equals(DateTime(2026, 6, 15)));
    });

    test('custom interval days', () {
      final rule = RecurrenceRule(type: RecurrenceType.customInterval, intervalDays: 10);
      final from = DateTime(2026, 1, 1);
      final next = nextDueDate(rule, from);
      expect(next, equals(DateTime(2026, 1, 11)));
    });

    test('returns null for none type', () {
      final rule = RecurrenceRule(type: RecurrenceType.none);
      expect(nextDueDate(rule, DateTime.now()), isNull);
    });

    test('distance-based returns null for date', () {
      final rule = RecurrenceRule(type: RecurrenceType.distanceKm, intervalKm: 5000);
      expect(nextDueDate(rule, DateTime.now()), isNull);
    });
  });

  group('nextDueOdometer', () {
    test('distanceKm recurrence', () {
      final rule = RecurrenceRule(type: RecurrenceType.distanceKm, intervalKm: 5000);
      final next = nextDueOdometer(rule, 10000);
      expect(next, equals(15000));
    });

    test('distanceMi recurrence', () {
      final rule = RecurrenceRule(type: RecurrenceType.distanceMi, intervalKm: 3000);
      final next = nextDueOdometer(rule, 5000);
      expect(next, equals(8000));
    });

    test('returns null for date-based types', () {
      final rule = RecurrenceRule(type: RecurrenceType.monthly);
      expect(nextDueOdometer(rule, 10000), isNull);
    });

    test('respects max occurrences', () {
      final rule = RecurrenceRule(
          type: RecurrenceType.distanceKm, intervalKm: 5000, maxOccurrences: 2);
      expect(nextDueOdometer(rule, 10000, occurrences: 1), isNotNull);
      expect(nextDueOdometer(rule, 10000, occurrences: 2), isNull);
    });
  });

  group('computeReminderState', () {
    test('disabled reminder', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        enabled: false, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now()), ReminderState.disabled);
    });

    test('overdue by date', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now()), ReminderState.overdue);
    });

    test('due today', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueDate: DateTime.now(),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now()), ReminderState.due);
    });

    test('due within window (days)', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueDate: DateTime.now().add(const Duration(days: 3)),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now()), ReminderState.due);
    });

    test('upcoming by date', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now()), ReminderState.upcoming);
    });

    test('overdue by odometer', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueOdometer: 10000,
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now(), currentOdometer: 10500),
          ReminderState.overdue);
    });

    test('due by odometer within 500km', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueOdometer: 10500,
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(computeReminderState(r, DateTime.now(), currentOdometer: 10200),
          ReminderState.due);
    });
  });

  group('completeReminder', () {
    test('advances due date for daily recurrence', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: RecurrenceRule(type: RecurrenceType.daily, intervalDays: 7),
        dueDate: DateTime(2026, 1, 1),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final completed = completeReminder(r, DateTime(2026, 1, 1));
      expect(completed.dueDate, equals(DateTime(2026, 1, 8)));
      expect(completed.lastDoneDate, equals(DateTime(2026, 1, 1)));
      expect(completed.state, ReminderState.upcoming);
    });

    test('advances due odometer for distance recurrence', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: RecurrenceRule(type: RecurrenceType.distanceKm, intervalKm: 5000),
        dueOdometer: 10000,
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final completed = completeReminder(r, DateTime.now(), odometerAtCompletion: 10000);
      expect(completed.dueOdometer, equals(15000));
      expect(completed.lastDoneOdometer, equals(10000));
    });

    test('sets completed if no recurrence', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: const RecurrenceRule(),
        dueDate: DateTime(2026, 1, 1),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final completed = completeReminder(r, DateTime(2026, 1, 1));
      expect(completed.dueDate, isNull);
      expect(completed.state, ReminderState.completed);
    });
  });

  group('skipReminder', () {
    test('advances due date without marking completed', () {
      final r = Reminder(
        id: '1', vehicleId: 'v1', title: 'Test',
        recurrence: RecurrenceRule(type: RecurrenceType.daily, intervalDays: 7),
        dueDate: DateTime(2026, 1, 1),
        enabled: true, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final skipped = skipReminder(r, DateTime(2026, 1, 1));
      expect(skipped.dueDate, equals(DateTime(2026, 1, 8)));
      expect(skipped.state, ReminderState.upcoming);
    });
  });
}
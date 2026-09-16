import '../models/reminder.dart';

/// Calculate the next due date/odometer for a [Reminder] based on its recurrence rule.
/// Returns null if the reminder should not recur (no rule or max occurrences reached).
DateTime? nextDueDate(RecurrenceRule rule, DateTime from,
    {int occurrences = 0}) {
  if (rule.type == RecurrenceType.none) return null;
  if (rule.maxOccurrences != null && occurrences >= rule.maxOccurrences!) {
    return null;
  }
  if (rule.endDate != null && from.isAfter(rule.endDate!)) return null;

  DateTime base = rule.startDate ?? from;

  switch (rule.type) {
    case RecurrenceType.daily:
      return _addDays(base, rule.intervalDays ?? 1, from);
    case RecurrenceType.weekly:
      return _nextWeekday(base, rule.weekDays ?? [from.weekday], from);
    case RecurrenceType.monthly:
      return _addMonths(base, rule.monthDay ?? from.day, from);
    case RecurrenceType.yearly:
      return _addYears(base, rule.yearMonth ?? from.month, rule.yearDay ?? from.day, from);
    case RecurrenceType.customInterval:
      return _addDays(base, rule.intervalDays ?? 1, from);
    case RecurrenceType.customDays:
      return _nextWeekday(base, rule.weekDays ?? [from.weekday], from);
    case RecurrenceType.distanceKm:
    case RecurrenceType.distanceMi:
      return null; // handled by odometer logic
    case RecurrenceType.none:
      return null;
  }
}

/// Calculate the next due odometer for distance-based reminders.
double? nextDueOdometer(RecurrenceRule rule, double fromOdometer,
    {int occurrences = 0}) {
  if (rule.type != RecurrenceType.distanceKm &&
      rule.type != RecurrenceType.distanceMi) {
    return null;
  }
  if (rule.maxOccurrences != null && occurrences >= rule.maxOccurrences!) {
    return null;
  }
  final interval = rule.intervalKm ?? 5000;
  return fromOdometer + interval;
}

DateTime _addDays(DateTime base, int days, DateTime after) {
  var next = base.add(Duration(days: days));
  while (next.isBefore(after) || next.isAtSameMomentAs(after)) {
    next = next.add(Duration(days: days));
  }
  return next;
}

DateTime _nextWeekday(DateTime base, List<int> weekDays, DateTime after) {
  final sortedDays = List<int>.from(weekDays)..sort();
  for (final wd in sortedDays) {
    var candidate = _nextWeekdayFrom(base, wd);
    if (candidate.isAfter(after)) {
      return candidate;
    }
  }
  // wrap to next week
  return _nextWeekdayFrom(base.add(const Duration(days: 7)), weekDays.first);
}

DateTime _nextWeekdayFrom(DateTime base, int weekday) {
  final diff = (weekday - base.weekday) % 7;
  return base.add(Duration(days: diff == 0 ? 0 : diff));
}

DateTime _addMonths(DateTime base, int day, DateTime after) {
  var next = DateTime(base.year, base.month, day);
  while (next.isBefore(after) || next.isAtSameMomentAs(after)) {
    next = DateTime(next.year, next.month + 1, day);
  }
  return next;
}

DateTime _addYears(DateTime base, int month, int day, DateTime after) {
  var next = DateTime(base.year, month, day);
  while (next.isBefore(after) || next.isAtSameMomentAs(after)) {
    next = DateTime(next.year + 1, month, day);
  }
  return next;
}

/// Compute the [ReminderState] based on current date, odometer, and last done values.
ReminderState computeReminderState(Reminder reminder, DateTime now,
    {double? currentOdometer}) {
  if (!reminder.enabled) return ReminderState.disabled;

  // If already completed this cycle
  if (reminder.state == ReminderState.completed &&
      reminder.lastDoneDate != null &&
      reminder.lastDoneDate!.isAfter(now.subtract(const Duration(days: 1)))) {
    return ReminderState.upcoming;
  }

  // Check date-based due
  if (reminder.dueDate != null) {
    final dueDateOnly =
        DateTime(reminder.dueDate!.year, reminder.dueDate!.month, reminder.dueDate!.day);
    final nowOnly = DateTime(now.year, now.month, now.day);
    if (nowOnly.isAfter(dueDateOnly)) return ReminderState.overdue;
    if (nowOnly.isAtSameMomentAs(dueDateOnly) ||
        dueDateOnly.difference(nowOnly).inDays <= 7) {
      return ReminderState.due;
    }
  }

  // Check odometer-based due
  if (reminder.dueOdometer != null && currentOdometer != null) {
    if (currentOdometer >= reminder.dueOdometer!) {
      return ReminderState.overdue;
    }
    if ((reminder.dueOdometer! - currentOdometer) <= 500) {
      return ReminderState.due;
    }
  }

  return ReminderState.upcoming;
}

/// Update a reminder after completion: set lastDone, advance due date/odometer,
/// and update state.
Reminder completeReminder(Reminder reminder, DateTime completedAt,
    {double? odometerAtCompletion}) {
  final rule = reminder.recurrence;
  final occurrences = 1; // TODO: track actual occurrences

  DateTime? nextDate;
  double? nextOdo;

  if (rule.type == RecurrenceType.distanceKm ||
      rule.type == RecurrenceType.distanceMi) {
    nextOdo = nextDueOdometer(rule, odometerAtCompletion ?? reminder.dueOdometer ?? 0,
        occurrences: occurrences);
  } else {
    nextDate = nextDueDate(rule, completedAt, occurrences: occurrences);
  }

  return reminder.copyWith(
    lastDoneDate: completedAt,
    lastDoneOdometer: odometerAtCompletion,
    dueDate: nextDate,
    dueOdometer: nextOdo,
    state: nextDate != null || nextOdo != null
        ? ReminderState.upcoming
        : ReminderState.completed,
    updatedAt: DateTime.now(),
  );
}

/// Update a reminder after skipping: advance due date/odometer but keep state upcoming.
Reminder skipReminder(Reminder reminder, DateTime skippedAt,
    {double? odometerAtSkip}) {
  final rule = reminder.recurrence;
  final occurrences = 1;

  DateTime? nextDate;
  double? nextOdo;

  if (rule.type == RecurrenceType.distanceKm ||
      rule.type == RecurrenceType.distanceMi) {
    nextOdo = nextDueOdometer(rule, odometerAtSkip ?? reminder.dueOdometer ?? 0,
        occurrences: occurrences);
  } else {
    nextDate = nextDueDate(rule, skippedAt, occurrences: occurrences);
  }

  return reminder.copyWith(
    dueDate: nextDate,
    dueOdometer: nextOdo,
    state: nextDate != null || nextOdo != null
        ? ReminderState.upcoming
        : ReminderState.completed,
    updatedAt: DateTime.now(),
  );
}
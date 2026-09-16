import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder.freezed.dart';
part 'reminder.g.dart';

@freezed
class Reminder with _$Reminder {
  const factory Reminder({
    required String id,
    required String vehicleId,
    required String title,
    @Default('') String description,
    @Default('custom') String category,
    required RecurrenceRule recurrence,
    DateTime? dueDate,
    double? dueOdometer,
    DateTime? lastDoneDate,
    double? lastDoneOdometer,
    @Default(ReminderState.upcoming) ReminderState state,
    @Default(true) bool enabled,
    @Default([]) List<String> notificationIds,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Reminder;

  factory Reminder.fromJson(Map<String, dynamic> json) =>
      _$ReminderFromJson(json);
}

@freezed
class RecurrenceRule with _$RecurrenceRule {
  const factory RecurrenceRule({
    @Default(RecurrenceType.none) RecurrenceType type,
    int? intervalDays,
    int? intervalKm,
    List<int>? weekDays,
    int? monthDay,
    int? yearMonth,
    int? yearDay,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
  }) = _RecurrenceRule;

  factory RecurrenceRule.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceRuleFromJson(json);
}

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  customInterval,
  customDays,
  distanceKm,
  distanceMi,
}

enum ReminderState {
  upcoming,
  due,
  overdue,
  completed,
  skipped,
  disabled,
}

extension RecurrenceTypeX on RecurrenceType {
  String get label {
    switch (this) {
      case RecurrenceType.none:
        return 'One-time';
      case RecurrenceType.daily:
        return 'Daily';
      case RecurrenceType.weekly:
        return 'Weekly';
      case RecurrenceType.monthly:
        return 'Monthly';
      case RecurrenceType.yearly:
        return 'Yearly';
      case RecurrenceType.customInterval:
        return 'Every X days';
      case RecurrenceType.customDays:
        return 'Specific weekdays';
      case RecurrenceType.distanceKm:
        return 'Every X km';
      case RecurrenceType.distanceMi:
        return 'Every X miles';
    }
  }
}

extension ReminderStateX on ReminderState {
  String get label {
    switch (this) {
      case ReminderState.upcoming:
        return 'Upcoming';
      case ReminderState.due:
        return 'Due';
      case ReminderState.overdue:
        return 'Overdue';
      case ReminderState.completed:
        return 'Completed';
      case ReminderState.skipped:
        return 'Skipped';
      case ReminderState.disabled:
        return 'Disabled';
    }
  }
}

extension ReminderX on Reminder {
  Map<String, Object?> toDbMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'title': title,
        'description': description,
        'category': category,
        'recurrence': jsonEncode(recurrence.toJson()),
        'due_date': dueDate?.toIso8601String(),
        'due_odometer': dueOdometer,
        'last_done_date': lastDoneDate?.toIso8601String(),
        'last_done_odometer': lastDoneOdometer,
        'state': state.name,
        'enabled': enabled ? 1 : 0,
        'notification_ids': jsonEncode(notificationIds),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

Reminder reminderFromDbMap(Map<String, Object?> map) => Reminder(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? 'custom',
      recurrence: RecurrenceRule.fromJson(
          jsonDecode(map['recurrence'] as String? ?? '{}')),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      dueOdometer:
          map['due_odometer'] != null ? (map['due_odometer'] as num).toDouble() : null,
      lastDoneDate: map['last_done_date'] != null
          ? DateTime.parse(map['last_done_date'] as String)
          : null,
      lastDoneOdometer:
          map['last_done_odometer'] != null ? (map['last_done_odometer'] as num).toDouble() : null,
      state: ReminderState.values.byName(map['state'] as String? ?? 'upcoming'),
      enabled: (map['enabled'] as int? ?? 1) == 1,
      notificationIds: List<String>.from(
          jsonDecode(map['notification_ids'] as String? ?? '[]')),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
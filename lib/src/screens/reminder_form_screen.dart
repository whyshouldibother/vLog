import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen({
    super.key,
    required this.vehicleId,
    this.reminder,
  });
  final String vehicleId;
  final Reminder? reminder;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends ConsumerState<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _categoryCtrl;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  int? _intervalDays;
  int? _intervalKm;
  List<int> _weekDays = [];
  int? _monthDay;
  int? _yearMonth;
  int? _yearDay;
  DateTime? _dueDate;
  double? _dueOdometer;
  DateTime? _startDate;
  DateTime? _endDate;
  int? _maxOccurrences;
  bool _saving = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.reminder != null;
    final r = widget.reminder;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _categoryCtrl = TextEditingController(text: r?.category ?? 'custom');
    if (r != null) {
      _recurrenceType = r.recurrence.type;
      _intervalDays = r.recurrence.intervalDays;
      _intervalKm = r.recurrence.intervalKm;
      _weekDays = List.from(r.recurrence.weekDays ?? []);
      _monthDay = r.recurrence.monthDay;
      _yearMonth = r.recurrence.yearMonth;
      _yearDay = r.recurrence.yearDay;
      _dueDate = r.dueDate;
      _dueOdometer = r.dueOdometer;
      _startDate = r.recurrence.startDate;
      _endDate = r.recurrence.endDate;
      _maxOccurrences = r.recurrence.maxOccurrences;
    } else {
      _dueDate = DateTime.now().add(const Duration(days: 7));
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final recurrence = RecurrenceRule(
      type: _recurrenceType,
      intervalDays: _intervalDays,
      intervalKm: _intervalKm,
      weekDays: _weekDays.isEmpty ? null : _weekDays,
      monthDay: _monthDay,
      yearMonth: _yearMonth,
      yearDay: _yearDay,
      startDate: _startDate,
      endDate: _endDate,
      maxOccurrences: _maxOccurrences,
    );

    final reminder = Reminder(
      id: widget.reminder?.id ?? const Uuid().v4(),
      vehicleId: widget.vehicleId,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      recurrence: recurrence,
      dueDate: _dueDate,
      dueOdometer: _dueOdometer,
      state: widget.reminder?.state ?? ReminderState.upcoming,
      enabled: true,
      notificationIds: widget.reminder?.notificationIds ?? [],
      createdAt: widget.reminder?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (_isEditing) {
        await ref
            .read(remindersNotifierProvider(widget.vehicleId).notifier)
            .updateReminder(reminder);
      } else {
        await ref
            .read(remindersNotifierProvider(widget.vehicleId).notifier)
            .addReminder(reminder);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Reminder' : 'Add Reminder')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_titleCtrl, 'Title', required: true),
            _field(_descCtrl, 'Description', required: false, maxLines: 2),
            _field(_categoryCtrl, 'Category', required: false),
            const SizedBox(height: 8),
            DropdownButtonFormField<RecurrenceType>(
              initialValue: _recurrenceType,
              decoration: const InputDecoration(labelText: 'Recurrence'),
              items: RecurrenceType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => _recurrenceType = v!),
            ),
            if (_recurrenceType == RecurrenceType.daily ||
                _recurrenceType == RecurrenceType.customInterval)
              _field(
                TextEditingController(text: _intervalDays?.toString() ?? ''),
                'Interval (days)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _intervalDays = int.tryParse(v),
              ),
            if (_recurrenceType == RecurrenceType.weekly ||
                _recurrenceType == RecurrenceType.customDays)
              _weekdaySelector(),
            if (_recurrenceType == RecurrenceType.monthly)
              _field(
                TextEditingController(text: _monthDay?.toString() ?? ''),
                'Day of month (1-31)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _monthDay = int.tryParse(v),
              ),
            if (_recurrenceType == RecurrenceType.yearly) ...[
              _field(
                TextEditingController(text: _yearMonth?.toString() ?? ''),
                'Month (1-12)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _yearMonth = int.tryParse(v),
              ),
              _field(
                TextEditingController(text: _yearDay?.toString() ?? ''),
                'Day of month (1-31)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _yearDay = int.tryParse(v),
              ),
            ],
            if (_recurrenceType == RecurrenceType.distanceKm ||
                _recurrenceType == RecurrenceType.distanceMi)
              _field(
                TextEditingController(text: _intervalKm?.toString() ?? ''),
                'Interval (km/mi)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _intervalKm = int.tryParse(v),
              ),
            if (_recurrenceType != RecurrenceType.none) ...[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Start date'),
                subtitle: Text(_startDate?.toString().split(' ').first ?? 'Not set'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _startDate = d);
                },
              ),
              ListTile(
                title: const Text('End date (optional)'),
                subtitle: Text(_endDate?.toString().split(' ').first ?? 'Not set'),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _endDate = d);
                },
              ),
              _field(
                TextEditingController(text: _maxOccurrences?.toString() ?? ''),
                'Max occurrences (optional)',
                keyboardType: TextInputType.number,
                onChanged: (v) => _maxOccurrences = int.tryParse(v),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const Text('Due trigger (at least one required)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              title: const Text('Due date'),
              subtitle: Text(_dueDate?.toString().split(' ').first ?? 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _dueDate = d);
              },
            ),
            ListTile(
              title: const Text('Due odometer (km)'),
              subtitle: Text(_dueOdometer?.toStringAsFixed(0) ?? 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                final v = await showDialog<double>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Due odometer'),
                    content: TextField(
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      controller:
                          TextEditingController(text: _dueOdometer?.toString()),
                      onChanged: (v) => _dueOdometer = double.tryParse(v),
                      decoration: const InputDecoration(labelText: 'Odometer'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                if (v != null) setState(() => _dueOdometer = v);
              },
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboardType,
      int maxLines = 1,
      bool required = true,
      void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _weekdaySelector() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Weekdays', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8,
          children: List.generate(7, (i) {
            final day = i + 1;
            final selected = _weekDays.contains(day);
            return FilterChip(
              label: Text(days[i]),
              selected: selected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _weekDays.add(day);
                  } else {
                    _weekDays.remove(day);
                  }
                });
              },
            );
          }),
        ),
      ],
    );
  }
}
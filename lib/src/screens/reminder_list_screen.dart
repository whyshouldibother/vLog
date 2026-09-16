import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import 'reminder_form_screen.dart';

class ReminderListScreen extends ConsumerWidget {
  const ReminderListScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ReminderFormScreen(vehicleId: vehicleId)),
        ),
        child: const Icon(Icons.add),
      ),
      body: remindersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (reminders) {
          if (reminders.isEmpty) {
            return const Center(
              child: Text('No reminders. Tap + to add one.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final r = reminders[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _stateColor(r.state),
                    child: Icon(r.state == ReminderState.completed
                        ? Icons.check
                        : Icons.schedule),
                  ),
                  title: Text(r.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.dueDate != null)
                        Text('Due: ${DateFormat('MMM d, y').format(r.dueDate!)}'),
                      if (r.dueOdometer != null)
                        Text('Due odometer: ${r.dueOdometer!.toStringAsFixed(0)} km'),
                      Text('State: ${r.state.label}',
                          style: TextStyle(color: _stateColor(r.state))),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ReminderFormScreen(vehicleId: vehicleId, reminder: r),
                          ),
                        );
                      } else if (value == 'complete') {
                        await ref
                            .read(remindersNotifierProvider(vehicleId).notifier)
                            .updateReminder(r.copyWith(
                              state: ReminderState.completed,
                              lastDoneDate: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ));
                      } else if (value == 'skip') {
                        await ref
                            .read(remindersNotifierProvider(vehicleId).notifier)
                            .updateReminder(r.copyWith(
                              state: ReminderState.skipped,
                              updatedAt: DateTime.now(),
                            ));
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete reminder?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref
                              .read(remindersNotifierProvider(vehicleId).notifier)
                              .deleteReminder(r.id);
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'complete', child: Text('Mark Complete')),
                      const PopupMenuItem(value: 'skip', child: Text('Skip')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _stateColor(ReminderState state) {
    switch (state) {
      case ReminderState.upcoming:
        return Colors.blue;
      case ReminderState.due:
        return Colors.orange;
      case ReminderState.overdue:
        return Colors.red;
      case ReminderState.completed:
        return Colors.green;
      case ReminderState.skipped:
        return Colors.grey;
      case ReminderState.disabled:
        return Colors.grey.shade400;
    }
  }
}
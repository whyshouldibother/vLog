import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/fuel_stats.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/units.dart';
import '../widgets/common.dart';
import 'add_fuel_screen.dart';
import 'add_record_screen.dart';
import 'reminder_list_screen.dart';
import 'vehicle_form_screen.dart';

class VehicleDetailScreen extends ConsumerWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesNotifierProvider);
    final settings = ref.watch(appSettingsNotifierProvider).valueOrNull;

    return vehicles.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: '$error'),
      ),
      data: (list) {
        final vehicle = list.where((v) => v.id == vehicleId).firstOrNull;
        if (vehicle == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off,
              title: 'Vehicle not found',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(vehicle.displayName),
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleFormScreen(vehicle: vehicle),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref, vehicle.id),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddMenu(context),
            icon: const Icon(Icons.add),
            label: const Text('Add entry'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (settings != null)
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Details',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        DetailRow(
                          label: 'Odometer',
                          value: formatDistance(
                              vehicle.currentOdometer, settings.distanceUnit),
                        ),
                        DetailRow(
                            label: 'Registration',
                            value: _orDash(vehicle.registrationNumber)),
                        DetailRow(
                            label: 'Make / model',
                            value: _orDash(
                                '${vehicle.make} ${vehicle.model}'.trim())),
                        DetailRow(
                            label: 'Variant', value: _orDash(vehicle.variant)),
                        DetailRow(
                            label: 'Year',
                            value: vehicle.year?.toString() ?? '—'),
                        DetailRow(label: 'VIN', value: _orDash(vehicle.vin)),
                        DetailRow(
                            label: 'Engine no.',
                            value: _orDash(vehicle.engineNumber)),
                        DetailRow(
                            label: 'Fuel type',
                            value: _orDash(vehicle.fuelType)),
                        if (vehicle.notes.trim().isNotEmpty)
                          DetailRow(label: 'Notes', value: vehicle.notes),
                      ],
                    ),
                  ),
                ),
              if (settings != null)
                _FuelStatsCard(vehicleId: vehicleId, settings: settings),
              const SizedBox(height: 16),
              _HistorySection(vehicleId: vehicleId),
            ],
          ),
        );
      },
    );
  }

  String _orDash(String value) => value.trim().isEmpty ? '—' : value.trim();

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.local_gas_station_outlined),
              title: const Text('Fuel entry'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AddFuelScreen(vehicleId: vehicleId)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.build_outlined),
              title: const Text('Service / repair / event'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          AddRecordScreen(vehicleId: vehicleId)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Reminders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          ReminderListScreen(vehicleId: vehicleId)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: const Text(
            'This permanently removes the vehicle and all of its records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(vehiclesNotifierProvider.notifier).deleteVehicle(id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _FuelStatsCard extends ConsumerWidget {
  const _FuelStatsCard({required this.vehicleId, required this.settings});
  final String vehicleId;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuelsAsync = ref.watch(fuelRecordsProvider(vehicleId));
    return fuelsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (fuels) {
        if (fuels.length < 2) return const SizedBox.shrink();
        final stats = computeFuelStats(fuels, settings);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fuel Economy',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      'Avg',
                      stats.averageEconomyString(settings.fuelEconomyUnit),
                    ),
                    _StatItem(
                      'Best',
                      stats.bestEconomyString(settings.fuelEconomyUnit),
                    ),
                    _StatItem(
                      'Latest',
                      stats.latestEconomyString(settings.fuelEconomyUnit) ?? '—',
                    ),
                    _StatItem(
                      'Total km',
                      stats.totalKm.toStringAsFixed(0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _HistorySection extends StatefulWidget {
  const _HistorySection({required this.vehicleId});
  final String vehicleId;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  RecordType? _filterType;

  void _editEntry(BuildContext context, WidgetRef ref, _HistoryItem item) {
    if (item.fuelRecord != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddFuelScreen(
            vehicleId: widget.vehicleId,
            initialRecord: item.fuelRecord,
          ),
        ),
      ).then((_) => setState(() {}));
    } else if (item.record != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddRecordScreen(
            vehicleId: widget.vehicleId,
            initialRecord: item.record,
          ),
        ),
      ).then((_) => setState(() {}));
    }
  }

  Future<void> _deleteEntry(BuildContext context, WidgetRef ref, _HistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This action cannot be undone.'),
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
    if (confirmed != true) return;

    try {
      if (item.fuelRecord != null) {
        await ref.read(fuelRepositoryProvider).delete(item.fuelRecord!.id);
        ref.invalidate(fuelRecordsProvider(widget.vehicleId));
      } else if (item.record != null) {
        await ref.read(recordRepositoryProvider).delete(item.record!.id);
        ref.invalidate(vehicleRecordsProvider(widget.vehicleId));
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final fuels = ref.watch(fuelRecordsProvider(widget.vehicleId));
        final records = ref.watch(vehicleRecordsProvider(widget.vehicleId));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('History',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  PopupMenuButton<RecordType?>(
                    tooltip: 'Filter',
                    initialValue: _filterType,
                    onSelected: (type) => setState(() => _filterType = type),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: null, child: Text('All types')),
                      ...RecordType.values.map(
                          (t) => PopupMenuItem(value: t, child: Text(t.label))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            fuels.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: '$e'),
              data: (fuelList) => records.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(message: '$e'),
                data: (recordList) {
                  final filteredRecords = _filterType == null
                      ? recordList
                      : recordList.where((r) => r.type == _filterType).toList();
                  final items = <_HistoryItem>[
                    ...fuelList.map((f) => _HistoryItem(
                          date: f.date,
                          icon: Icons.local_gas_station_outlined,
                          title:
                              '${f.quantity.toStringAsFixed(1)} L · ${formatCurrency(f.totalCost, f.currency)}',
                          subtitle: '${f.odometer.toStringAsFixed(0)} km · ${f.station}',
                          fuelRecord: f,
                        )),
                    ...filteredRecords.map((r) => _HistoryItem(
                          date: r.date,
                          icon: r.type.icon,
                          title: r.title.isNotEmpty ? r.title : r.type.label,
                          subtitle: [
                            if (r.odometer != null)
                              '${r.odometer!.toStringAsFixed(0)} km',
                            if (r.cost != null)
                              formatCurrency(r.cost, r.currency),
                            r.provider,
                          ]
                              .where((e) => e.isNotEmpty)
                              .join(' · '),
                          record: r,
                        )),
                  ]..sort((a, b) => b.date.compareTo(a.date));

                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: EmptyState(
                        icon: Icons.history,
                        title: 'No entries yet',
                      ),
                    );
                  }
                  return Column(
                    children: items
                        .map((item) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                radius: 18,
                                child: Icon(item.icon, size: 20),
                              ),
                              title: Text(item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: item.subtitle.isNotEmpty
                                  ? Text(item.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)
                                  : null,
                              trailing: Text(formatDate(item.date, 'dd/MM/yy'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      )),
                              onTap: () => _editEntry(context, ref, item),
                              onLongPress: () => _deleteEntry(context, ref, item),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryItem {
  final DateTime date;
  final IconData icon;
  final String title;
  final String subtitle;
  final FuelRecord? fuelRecord;
  final Record? record;
  const _HistoryItem({
    required this.date,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.fuelRecord,
    this.record,
  });
}
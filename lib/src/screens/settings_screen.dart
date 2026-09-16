import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/backup.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(appSettingsNotifierProvider.notifier);
    return ListView(
      children: [
        _SectionHeader('Appearance'),
        _EnumTile(
          icon: Icons.brightness_6,
          title: 'Theme',
          value: _themeLabel(settings.themeMode),
          onChanged: (v) => notifier
              .updateSettings(settings.copyWith(themeMode: AppThemeMode.values[v])),
          items: AppThemeMode.values.map(_themeLabel).toList(),
        ),
        const Divider(),
        _SectionHeader('Currency'),
        _EnumTile(
          icon: Icons.monetization_on_outlined,
          title: 'Currency',
          value: settings.currency,
          onChanged: (v) =>
              notifier.updateSettings(settings.copyWith(currency: kCurrencies[v])),
          items: kCurrencies,
        ),
        const Divider(),
        _SectionHeader('Units'),
        _EnumTile(
          icon: Icons.straighten,
          title: 'Distance',
          value: settings.distanceUnit.label,
          onChanged: (v) => notifier
              .updateSettings(settings.copyWith(distanceUnit: DistanceUnit.values[v])),
          items: DistanceUnit.values.map((e) => e.label).toList(),
        ),
        _EnumTile(
          icon: Icons.local_drink_outlined,
          title: 'Volume',
          value: settings.volumeUnit.label,
          onChanged: (v) => notifier
              .updateSettings(settings.copyWith(volumeUnit: VolumeUnit.values[v])),
          items: VolumeUnit.values.map((e) => e.label).toList(),
        ),
        _EnumTile(
          icon: Icons.speed,
          title: 'Fuel economy',
          value: settings.fuelEconomyUnit.label,
          onChanged: (v) => notifier.updateSettings(
              settings.copyWith(fuelEconomyUnit: FuelEconomyUnit.values[v])),
          items: FuelEconomyUnit.values.map((e) => e.label).toList(),
        ),
        _EnumTile(
          icon: Icons.swap_horiz,
          title: 'Odometer entry mode',
          value: settings.odometerEntryMode.label,
          onChanged: (v) => notifier.updateSettings(
              settings.copyWith(odometerEntryMode: OdometerEntryMode.values[v])),
          items: OdometerEntryMode.values.map((e) => e.label).toList(),
        ),
        const Divider(),
        _SectionHeader('Date'),
        _EnumTile(
          icon: Icons.calendar_today_outlined,
          title: 'Date format',
          value: settings.dateFormat,
          onChanged: (v) =>
              notifier.updateSettings(settings.copyWith(dateFormat: kDateFormats[v])),
          items: kDateFormats,
        ),
        const Divider(),
        _SectionHeader('Backup & Restore'),
        _BackupSection(),
      ],
    );
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              )),
    );
  }
}

class _EnumTile extends StatelessWidget {
  const _EnumTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.items,
  });
  final IconData icon;
  final String title;
  final String value;
  final void Function(int index) onChanged;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        onChanged: (v) {
          if (v == null) return;
          onChanged(items.indexOf(v));
        },
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ),
    );
  }
}

class _BackupSection extends ConsumerStatefulWidget {
  const _BackupSection();

  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _exporting = false;
  bool _importing = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final vehicles = await ref.read(vehicleRepositoryProvider).getAll();
      final fuelRecords = <FuelRecord>[];
      final records = <Record>[];
      final reminders = <Reminder>[];
      for (final v in vehicles) {
        fuelRecords.addAll(await ref.read(fuelRepositoryProvider).getByVehicle(v.id));
        records.addAll(await ref.read(recordRepositoryProvider).getByVehicle(v.id));
        reminders.addAll(await ref.read(reminderRepositoryProvider).getByVehicle(v.id));
      }
      final settings = ref.read(appSettingsNotifierProvider).valueOrNull ?? AppSettings();

      final json = BackupExport.encode(
        vehicles: vehicles,
        fuelRecords: fuelRecords,
        records: records,
        reminders: reminders,
        settings: settings,
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/vlog_backup_${DateTime.now().toIso8601String().split('T').first}.json');
      await file.writeAsString(json);

      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: 'vLog backup');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    // For now, we'll use a simple file picker approach
    // In a real app, you'd use file_picker package
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().where((f) => f.path.endsWith('.json')).cast<File>().toList();
    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No backup files found in documents directory')),
        );
      }
      return;
    }

    // Show file picker dialog
    final selected = await showDialog<File>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select backup file'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: files.length,
            itemBuilder: (context, index) {
              final f = files[index];
              return ListTile(
                title: Text(f.path.split('/').last),
                subtitle: Text('Modified: ${f.lastModifiedSync().toString().split('.').first}'),
                onTap: () => Navigator.pop(context, f),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );

    if (selected == null) return;

    setState(() => _importing = true);
    try {
      final jsonString = await selected.readAsString();
      final strategy = await _showStrategyDialog() ?? BackupImport.mergeStrategyMerge;

      final result = await BackupImport.importFromJson(
        jsonString,
        strategy: strategy,
        vehicleRepo: ref.read(vehicleRepositoryProvider),
        fuelRepo: ref.read(fuelRepositoryProvider),
        recordRepo: ref.read(recordRepositoryProvider),
        reminderRepo: ref.read(reminderRepositoryProvider),
        settingsRepo: ref.read(settingsRepositoryProvider),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? 'Import successful:\n${result.summary}' : 'Import failed: ${result.error}'),
            duration: const Duration(seconds: 5),
          ),
        );
        ref.invalidate(vehiclesNotifierProvider);
        ref.invalidate(appSettingsNotifierProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<String?> _showStrategyDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import strategy'),
        content: const Text('How should existing data be handled?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, BackupImport.mergeStrategyMerge),
            child: const Text('Merge (keep existing, add new)'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, BackupImport.mergeStrategyReplace),
            child: const Text('Replace (delete all, import fresh)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Export backup'),
          subtitle: const Text('Save all data to JSON file'),
          trailing: _exporting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _exporting ? null : _export,
        ),
        ListTile(
          leading: const Icon(Icons.upload_outlined),
          title: const Text('Import backup'),
          subtitle: const Text('Restore data from JSON file'),
          trailing: _importing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right),
          onTap: _importing ? null : _import,
        ),
      ],
    );
  }
}

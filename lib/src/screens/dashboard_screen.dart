import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../services/dashboard_stats.dart';
import '../services/fuel_stats.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../utils/units.dart';
import '../widgets/common.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedVehicleId;
  DateTimeRange? _dateRange;
  String? _selectedFuelType;
  String? _selectedStation;
  String _chartType = 'overview';

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesNotifierProvider);
    final settingsAsync = ref.watch(appSettingsNotifierProvider);

    return Scaffold(
      backgroundColor: context.cs.surface,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: vehiclesAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return SliverFillRemaining(
                    child: EmptyState(
                      icon: Icons.dashboard_outlined,
                      title: 'No vehicles yet',
                      message: 'Add a vehicle to see dashboard',
                      action: FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Vehicle'),
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),
                  );
                }
                return settingsAsync.when(
                  loading: () => const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    child: Center(child: Text('Error: $e')),
                  ),
                  data: (settings) {
                    final filteredVehicles = _selectedVehicleId != null
                        ? vehicles.where((v) => v.id == _selectedVehicleId).toList()
                        : vehicles;

                    final allFuelRecordsAsync = ref.watch(allFuelRecordsProvider);
                    final allRecordsAsync = ref.watch(allRecordsProvider);
                    final allRemindersAsync = ref.watch(allRemindersProvider);

                    return allFuelRecordsAsync.when(
                      loading: () => const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => SliverFillRemaining(
                        child: Center(child: Text('Error: $e')),
                      ),
                      data: (allFuelRecords) => allRecordsAsync.when(
                        loading: () => const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => SliverFillRemaining(
                          child: Center(child: Text('Error: $e')),
                        ),
                        data: (allRecords) => allRemindersAsync.when(
                          loading: () => const SliverFillRemaining(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => SliverFillRemaining(
                            child: Center(child: Text('Error: $e')),
                          ),
                          data: (allReminders) {
                            final filteredFuel = _filterFuelRecords(allFuelRecords, filteredVehicles);
                            final filteredRecords = _filterRecords(allRecords, filteredVehicles);
                            final filteredReminders = _filterReminders(allReminders, filteredVehicles);

                            final stats = computeDashboardStats(
                              vehicles: filteredVehicles,
                              allFuelRecords: filteredFuel,
                              allRecords: filteredRecords,
                              allReminders: filteredReminders,
                              settings: settings,
                            );

                            return _DashboardBody(
                              stats: stats,
                              settings: settings,
                              vehicles: filteredVehicles,
                              allFuelRecords: filteredFuel,
                              allRecords: filteredRecords,
                              selectedChartType: _chartType,
                              onChartTypeChanged: (type) => setState(() => _chartType = type),
                              activeFilters: _getActiveFilters(vehicles),
                              onClearFilters: _clearFilters,
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      snap: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: context.cs.surface,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildAppBarBackground(context),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: Text(
          'Dashboard',
          style: context.tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.5,
            color: context.cs.onSurface,
          ),
        ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
      ),
      actions: [
        _buildFilterButton(context).animate().fadeIn(delay: 300.ms).scale(),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildAppBarBackground(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cs.primaryContainer.withValues(alpha: 0.3),
            context.cs.secondaryContainer.withValues(alpha: 0.2),
            context.cs.tertiaryContainer.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.cs.primary.withValues(alpha: 0.15),
                    context.cs.primary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    context.cs.tertiary.withValues(alpha: 0.12),
                    context.cs.tertiary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    final hasFilters = _hasActiveFilters();
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showFilterBottomSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: hasFilters
                  ? context.cs.primaryContainer.withValues(alpha: 0.5)
                  : context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
              border: Border.all(
                color: hasFilters
                    ? context.cs.primary.withValues(alpha: 0.3)
                    : context.cs.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list_rounded,
                  size: 20,
                  color: hasFilters ? context.cs.primary : context.cs.onSurfaceVariant,
                ),
                if (hasFilters) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.cs.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<FuelRecord> _filterFuelRecords(List<FuelRecord> records, List<Vehicle> vehicles) {
    var filtered = records.where((r) => vehicles.any((v) => v.id == r.vehicleId)).toList();
    if (_dateRange != null) {
      filtered = filtered.where((r) =>
          r.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
          r.date.isBefore(_dateRange!.end.add(const Duration(days: 1)))).toList();
    }
    if (_selectedFuelType != null) {
      filtered = filtered.where((r) => r.fuelType == _selectedFuelType).toList();
    }
    if (_selectedStation != null) {
      filtered = filtered.where((r) => r.station == _selectedStation).toList();
    }
    return filtered;
  }

  List<Record> _filterRecords(List<Record> records, List<Vehicle> vehicles) {
    var filtered = records.where((r) => vehicles.any((v) => v.id == r.vehicleId)).toList();
    if (_dateRange != null) {
      filtered = filtered.where((r) =>
          r.date.isAfter(_dateRange!.start.subtract(const Duration(days: 1))) &&
          r.date.isBefore(_dateRange!.end.add(const Duration(days: 1)))).toList();
    }
    return filtered;
  }

  List<Reminder> _filterReminders(List<Reminder> reminders, List<Vehicle> vehicles) {
    return reminders.where((r) => vehicles.any((v) => v.id == r.vehicleId)).toList();
  }

  Map<String, dynamic> _getActiveFilters(List<Vehicle> vehicles) {
    final filters = <String, dynamic>{};
    if (_selectedVehicleId != null) {
      final v = vehicles.firstWhere((v) => v.id == _selectedVehicleId);
      filters['Vehicle'] = v.displayName;
    }
    if (_dateRange != null) {
      filters['Date Range'] = '${DateFormat('dd/MM/yyyy').format(_dateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange!.end)}';
    }
    if (_selectedFuelType != null) filters['Fuel Type'] = _selectedFuelType;
    if (_selectedStation != null) filters['Station'] = _selectedStation;
    return filters;
  }

  void _clearFilters() {
    setState(() {
      _selectedVehicleId = null;
      _dateRange = null;
      _selectedFuelType = null;
      _selectedStation = null;
    });
  }

  bool _hasActiveFilters() {
    return _selectedVehicleId != null || _dateRange != null || _selectedFuelType != null || _selectedStation != null;
  }

  void _showFilterBottomSheet() {
    final vehicles = ref.read(vehiclesNotifierProvider).valueOrNull ?? [];
    final allFuelTypes = ref.read(fuelTypesProvider).valueOrNull ?? [];
    final allStations = ref.read(stationsProvider).valueOrNull ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: context.cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.cs.primary, context.cs.secondary],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.filter_list_rounded, color: context.cs.onPrimary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filters',
                              style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Customize your dashboard view',
                              style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ).animate().fadeIn().slideX(),
                  const SizedBox(height: 24),

                  // Vehicle selector
                  _buildFilterDropdown(
                    label: 'Vehicle',
                    value: _selectedVehicleId,
                    icon: Icons.directions_car_rounded,
                    hint: 'All Vehicles',
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Vehicles')),
                      ...vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.displayName))),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedVehicleId = v);
                      setModalState(() {});
                    },
                  ).animate().fadeIn(delay: 100.ms).slideX(),

                  const SizedBox(height: 16),

                  // Date range selector
                  _buildDateRangeSelector(setModalState).animate().fadeIn(delay: 150.ms).slideX(),

                  const SizedBox(height: 16),

                  // Fuel type selector
                  if (allFuelTypes.isNotEmpty)
                    _buildFilterDropdown(
                      label: 'Fuel Type',
                      value: _selectedFuelType,
                      icon: Icons.local_gas_station_rounded,
                      hint: 'All Fuel Types',
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Fuel Types')),
                        ...allFuelTypes.map((f) => DropdownMenuItem(value: f, child: Text(f))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedFuelType = v);
                        setModalState(() {});
                      },
                    ).animate().fadeIn(delay: 200.ms).slideX(),

                  if (allFuelTypes.isNotEmpty) const SizedBox(height: 16),

                  // Station selector
                  if (allStations.isNotEmpty)
                    _buildFilterDropdown(
                      label: 'Station',
                      value: _selectedStation,
                      icon: Icons.place_rounded,
                      hint: 'All Stations',
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Stations')),
                        ...allStations.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      ],
                      onChanged: (v) {
                        setState(() => _selectedStation = v);
                        setModalState(() {});
                      },
                    ).animate().fadeIn(delay: 250.ms).slideX(),

                  if (allStations.isNotEmpty) const SizedBox(height: 16),

                  const SizedBox(height: 8),

                  // Clear button
                  if (_hasActiveFilters())
                    OutlinedButton.icon(
                      onPressed: () {
                        _clearFilters();
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('Clear All Filters'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ).animate().fadeIn(delay: 300.ms).scale(),

                  const SizedBox(height: 16),

                  // Done button
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Done'),
                  ).animate().fadeIn(delay: 350.ms).scale(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required IconData icon,
    required String hint,
    required List<DropdownMenuItem<String?>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: context.cs.primary),
            const SizedBox(width: 8),
            Text(label, style: context.tt.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: DropdownButtonFormField<String?>(
            isExpanded: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              filled: false,
            ),
            initialValue: value,
            hint: Text(hint),
            items: items,
            onChanged: onChanged,
            icon: Icon(Icons.arrow_drop_down_rounded, color: context.cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 18, color: context.cs.primary),
            const SizedBox(width: 8),
            Text('Date Range', style: context.tt.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDateRange: _dateRange,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    appBarTheme: AppBarTheme(backgroundColor: context.cs.surface),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                setState(() => _dateRange = picked);
                setModalState(() {});
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('dd MMM yyyy').format(_dateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}',
                      style: context.tt.bodyLarge?.copyWith(
                        color: _dateRange == null ? context.cs.onSurfaceVariant : context.cs.onSurface,
                      ),
                    ),
                  ),
                  if (_dateRange != null)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        setState(() => _dateRange = null);
                        setModalState(() {});
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: context.cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.stats,
    required this.settings,
    required this.vehicles,
    required this.allFuelRecords,
    required this.allRecords,
    required this.selectedChartType,
    required this.onChartTypeChanged,
    required this.activeFilters,
    required this.onClearFilters,
  });
  final DashboardStats stats;
  final AppSettings settings;
  final List<Vehicle> vehicles;
  final List<FuelRecord> allFuelRecords;
  final List<Record> allRecords;
  final String selectedChartType;
  final ValueChanged<String> onChartTypeChanged;
  final Map<String, dynamic> activeFilters;
  final VoidCallback onClearFilters;

  static const List<Map<String, dynamic>> _chartTypes = [
    {'id': 'overview', 'label': 'Overview', 'icon': Icons.dashboard_rounded},
    {'id': 'fuel_consumption', 'label': 'Fuel', 'icon': Icons.local_gas_station_rounded},
    {'id': 'cost_analysis', 'label': 'Costs', 'icon': Icons.attach_money_rounded},
    {'id': 'vehicle_comparison', 'label': 'Compare', 'icon': Icons.compare_arrows_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final currency = settings.currency;
    final distanceUnit = settings.distanceUnit;
    final sortedFuel = [...allFuelRecords]..sort((a, b) => a.date.compareTo(b.date));
    final segments = buildSegments(sortedFuel);

    return SliverList(
      delegate: SliverChildListDelegate([
        // Active filters chips
        if (activeFilters.isNotEmpty) ...[
          _buildActiveFiltersChips(context).animate().fadeIn().slideY(begin: -0.2),
          const SizedBox(height: 16),
        ],

        // Summary stats with breathing animation
        _buildAnimatedSummaryCard(context, currency, distanceUnit)
            .animate()
            .fadeIn(delay: 100.ms)
            .slideY(begin: 0.2),

        const SizedBox(height: 24),

        // Chart type selector
        _buildChartTypeSelector(context).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

        const SizedBox(height: 24),

        // Charts section with smooth transitions
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(selectedChartType),
            child: _buildChartSection(context, segments, currency, distanceUnit),
          ),
        ),

        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _buildActiveFiltersChips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.cs.primaryContainer.withValues(alpha: 0.3),
            context.cs.secondaryContainer.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.cs.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 16, color: context.cs.primary),
              const SizedBox(width: 8),
              Text(
                'Active Filters',
                style: context.tt.labelMedium?.copyWith(color: context.cs.primary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onClearFilters,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.cs.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear_all_rounded, size: 14, color: context.cs.error),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: context.tt.labelSmall?.copyWith(color: context.cs.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeFilters.entries.map((entry) {
              return Chip(
                avatar: Icon(
                  entry.key == 'Vehicle' ? Icons.directions_car_rounded :
                  entry.key == 'Date Range' ? Icons.calendar_today_rounded :
                  entry.key == 'Fuel Type' ? Icons.local_gas_station_rounded :
                  Icons.place_rounded,
                  size: 16,
                  color: context.cs.onPrimaryContainer,
                ),
                label: Text('${entry.key}: ${entry.value}'),
                backgroundColor: context.cs.primaryContainer.withValues(alpha: 0.5),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ).animate().scale(delay: (activeFilters.keys.toList().indexOf(entry.key) * 50).ms);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSummaryCard(BuildContext context, String currency, DistanceUnit distanceUnit) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cs.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
            context.cs.secondaryContainer.withValues(alpha: isDark ? 0.2 : 0.3),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: context.cs.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -5,
          ),
        ],
        border: Border.all(
          color: context.cs.primary.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.cs.surface.withValues(alpha: 0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BreathingStatCard(
                      label: 'Vehicles',
                      value: stats.vehicleCount.toString(),
                      icon: Icons.directions_car_rounded,
                      index: 0,
                    ),
                    _BreathingStatCard(
                      label: 'Fuel Entries',
                      value: stats.totalFuelEntries.toString(),
                      icon: Icons.local_gas_station_rounded,
                      index: 1,
                    ),
                    _BreathingStatCard(
                      label: 'Services',
                      value: stats.totalServiceEntries.toString(),
                      icon: Icons.build_rounded,
                      index: 2,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        context.cs.outlineVariant.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BreathingStatCard(
                      label: 'Fuel Cost',
                      value: formatCurrency(stats.totalFuelCost, currency),
                      icon: Icons.account_balance_wallet_rounded,
                      index: 3,
                    ),
                    _BreathingStatCard(
                      label: 'Service Cost',
                      value: formatCurrency(stats.totalServiceCost, currency),
                      icon: Icons.handyman_rounded,
                      index: 4,
                    ),
                    _BreathingStatCard(
                      label: 'Distance',
                      value: formatDistance(stats.totalOdometer, distanceUnit),
                      icon: Icons.straighten_rounded,
                      index: 5,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChartTypeSelector(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _chartTypes.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final type = _chartTypes[index];
          final isSelected = selectedChartType == type['id'];

          return _AnimatedChartChip(
            label: type['label'] as String,
            icon: type['icon'] as IconData,
            isSelected: isSelected,
            onTap: () => onChartTypeChanged(type['id'] as String),
            index: index,
          );
        },
      ),
    );
  }

  Widget _buildChartSection(BuildContext context, List<MileageSegment> segments,
      String currency, DistanceUnit distanceUnit) {
    switch (selectedChartType) {
      case 'fuel_consumption':
        return _buildFuelConsumptionCharts(context, segments, currency, distanceUnit);
      case 'cost_analysis':
        return _buildCostAnalysisCharts(context, currency, distanceUnit);
      case 'vehicle_comparison':
        return _buildVehicleComparisonCharts(context, currency, distanceUnit);
      default:
        return _buildOverviewCharts(context, segments, currency, distanceUnit);
    }
  }

  Widget _buildOverviewCharts(BuildContext context, List<MileageSegment> segments,
      String currency, DistanceUnit distanceUnit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats.fuelCostByMonth.isNotEmpty) ...[
          _buildGlassChartCard(
            context,
            'Fuel Cost Over Time',
            Icons.show_chart_rounded,
            _AutoScaleLineChart(
              data: () {
                final sortedEntries = stats.fuelCostByMonth.entries.toList()
                  ..sort((a, b) => a.key.compareTo(b.key));
                return sortedEntries.asMap().entries
                    .map((e) => MapEntry(e.key.toDouble(), e.value.value))
                    .toList();
              }(),
              currency: currency,
              xAxisLabel: 'Month',
              yAxisLabel: 'Cost',
              getXLabel: (idx, entries) {
                final sortedKeys = stats.fuelCostByMonth.keys.toList()..sort();
                final key = sortedKeys[idx];
                final parts = key.split('-');
                return '${parts[1]}/${parts[0].substring(2)}';
              },
              getYLabel: (value) => '${currencySymbol(currency)}${value.toStringAsFixed(0)}',
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        if (segments.isNotEmpty) ...[
          _buildGlassChartCard(
            context,
            'Fuel Economy (${settings.fuelEconomyUnit.label})',
            Icons.speed_rounded,
            _AutoScaleLineChart(
              data: segments.asMap().entries
                  .where((e) => e.value.valid)
                  .map((e) => MapEntry(e.key.toDouble(), e.value.kmPerLiter))
                  .toList(),
              xAxisLabel: 'Fill #',
              yAxisLabel: 'Economy',
              getXLabel: (idx, entries) => '#${idx + 1}',
              getYLabel: (value) => value.toStringAsFixed(1),
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        if (stats.expensesByCategory.isNotEmpty) ...[
          _buildGlassChartCard(
            context,
            'Expenses by Category',
            Icons.pie_chart_rounded,
            _ExpensePieChart(data: stats.expensesByCategory, currency: currency),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
        ],
      ],
    );
  }

  Widget _buildFuelConsumptionCharts(BuildContext context, List<MileageSegment> segments,
      String currency, DistanceUnit distanceUnit) {
    final validSegments = segments.where((s) => s.valid).toList();

    if (validSegments.isEmpty) {
      return _buildEmptyChartState(
        context,
        'Need at least 2 fuel entries',
        'Add more fuel records to see consumption charts',
        Icons.local_gas_station_rounded,
      ).animate().fadeIn().scale();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassChartCard(
          context,
          'Economy per Fill (${settings.fuelEconomyUnit.label})',
          Icons.trending_up_rounded,
          _AutoScaleLineChart(
            data: validSegments.asMap().entries
                .map((e) => MapEntry(e.key.toDouble(), e.value.kmPerLiter))
                .toList(),
            xAxisLabel: 'Fill #',
            yAxisLabel: 'Economy (${settings.fuelEconomyUnit.label})',
            getXLabel: (idx, _) => '#${idx + 1}',
            getYLabel: (value) => value.toStringAsFixed(1),
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildGlassChartCard(
          context,
          'Distance vs Fuel Used',
          Icons.scatter_plot_rounded,
          _AutoScaleScatterChart(
            data: validSegments.map((s) => FlSpot(s.kmDriven, s.litersUsed)).toList(),
            xLabel: 'Distance (${distanceUnit.label})',
            yLabel: 'Fuel (L)',
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildGlassChartCard(
          context,
          'Cost per KM',
          Icons.money_rounded,
          _AutoScaleLineChart(
            data: validSegments.asMap().entries
                .map((e) => MapEntry(e.key.toDouble(), e.value.costPerKm))
                .toList(),
            xAxisLabel: 'Fill #',
            yAxisLabel: 'Cost per KM',
            getXLabel: (idx, _) => '#${idx + 1}',
            getYLabel: (value) => '${currencySymbol(currency)}${value.toStringAsFixed(2)}',
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
      ],
    );
  }

  Widget _buildCostAnalysisCharts(BuildContext context, String currency, DistanceUnit distanceUnit) {
    final totalFuelCost = stats.totalFuelCost;
    final totalServiceCost = stats.totalServiceCost;
    final totalCost = totalFuelCost + totalServiceCost;

    final vehicleCosts = <String, double>{};
    final vehicleFuelCosts = <String, double>{};
    final vehicleServiceCosts = <String, double>{};
    final vehicleDistances = <String, double>{};

    for (final v in vehicles) {
      final vFuel = allFuelRecords.where((f) => f.vehicleId == v.id).toList();
      final vRecords = allRecords.where((r) => r.vehicleId == v.id).toList();
      final vFuelCost = vFuel.fold(0.0, (a, b) => a + b.totalCost);
      final vServiceCost = vRecords.fold(0.0, (a, b) => a + (b.cost ?? 0));
      final vDistance = vFuel.length >= 2 ? vFuel.first.odometer - vFuel.last.odometer : 0.0;

      vehicleCosts[v.displayName] = vFuelCost + vServiceCost;
      vehicleFuelCosts[v.displayName] = vFuelCost;
      vehicleServiceCosts[v.displayName] = vServiceCost;
      vehicleDistances[v.displayName] = vDistance.abs();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (totalCost > 0) ...[
          _buildGlassChartCard(
            context,
            'Total Cost Breakdown',
            Icons.pie_chart_rounded,
            _ExpensePieChart(
              data: {
                'Fuel': totalFuelCost,
                'Service/Repair': totalServiceCost,
              },
              currency: currency,
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        if (vehicleCosts.values.any((v) => v > 0)) ...[
          _buildGlassChartCard(
            context,
            'Cost by Vehicle',
            Icons.bar_chart_rounded,
            _AutoScaleBarChart(
              data: vehicleCosts.entries.toList(),
              getLabel: (e) => e.key,
              getValue: (e) => e.value,
              currency: currency,
              xAxisLabel: 'Vehicle',
              yAxisLabel: 'Total Cost',
            ),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          _buildGlassChartCard(
            context,
            'Fuel vs Service Cost',
            Icons.compare_rounded,
            _GroupedBarChart(
              labels: vehicleCosts.keys.toList(),
              series: [
                BarSeries('Fuel', vehicleFuelCosts.values.toList(), Colors.blue),
                BarSeries('Service', vehicleServiceCosts.values.toList(), Colors.orange),
              ],
              currency: currency,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        if (vehicleDistances.values.any((v) => v > 0)) ...[
          _buildGlassChartCard(
            context,
            'Distance Traveled (${distanceUnit.label})',
            Icons.route_rounded,
            _AutoScaleBarChart(
              data: vehicleDistances.entries.toList(),
              getLabel: (e) => e.key,
              getValue: (e) => e.value,
              showValue: true,
              xAxisLabel: 'Vehicle',
              yAxisLabel: 'Distance (${distanceUnit.label})',
            ),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
        ],
        if (vehicleCosts.values.any((v) => v > 0) && vehicleDistances.values.any((v) => v > 0)) ...[
          _buildGlassChartCard(
            context,
            'Cost per Distance by Vehicle',
            Icons.money_off_rounded,
            _AutoScaleBarChart(
              data: vehicleCosts.entries
                  .where((e) => vehicleDistances[e.key]! > 0)
                  .map((e) => MapEntry(e.key, e.value / vehicleDistances[e.key]!))
                  .toList(),
              getLabel: (e) => e.key,
              getValue: (e) => e.value,
              currency: currency,
              valueSuffix: '/${distanceUnit.label}',
              xAxisLabel: 'Vehicle',
              yAxisLabel: 'Cost / ${distanceUnit.label}',
            ),
          ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
        ],
      ],
    );
  }

  Widget _buildVehicleComparisonCharts(BuildContext context, String currency, DistanceUnit distanceUnit) {
    final vehicleStats = <String, _VehicleStat>{};
    final vehicleCosts = <String, double>{};
    final vehicleEconomies = <String, double>{};
    final vehicleFuel = <String, double>{};
    final vehicleDistances = <String, double>{};

    for (final v in vehicles) {
      final vFuel = allFuelRecords.where((f) => f.vehicleId == v.id).toList();
      final vRecords = allRecords.where((r) => r.vehicleId == v.id).toList();
      final vFuelCost = vFuel.fold(0.0, (a, b) => a + b.totalCost);
      final vServiceCost = vRecords.fold(0.0, (a, b) => a + (b.cost ?? 0));
      final vTotalCost = vFuelCost + vServiceCost;
      final vTotalFuel = vFuel.fold(0.0, (a, b) => a + b.quantity);
      final vDistance = vFuel.length >= 2 ? (vFuel.first.odometer - vFuel.last.odometer).abs() : 0.0;
      final avgEconomy = vFuel.length >= 2 && vTotalFuel > 0 ? vDistance / vTotalFuel : 0.0;

      vehicleStats[v.displayName] = _VehicleStat(
        totalCost: vTotalCost,
        fuelCost: vFuelCost,
        serviceCost: vServiceCost,
        totalFuel: vTotalFuel,
        distance: vDistance,
        avgEconomy: avgEconomy,
        fillCount: vFuel.length,
      );
      vehicleCosts[v.displayName] = vTotalCost;
      if (avgEconomy > 0) vehicleEconomies[v.displayName] = avgEconomy;
      vehicleFuel[v.displayName] = vTotalFuel;
      vehicleDistances[v.displayName] = vDistance;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGlassChartCard(
          context,
          'Total Cost by Vehicle',
          Icons.account_balance_wallet_rounded,
          _AutoScaleBarChart(
            data: vehicleCosts.entries.toList(),
            getLabel: (e) => e.key,
            getValue: (e) => e.value,
            currency: currency,
            xAxisLabel: 'Vehicle',
            yAxisLabel: 'Total Cost',
          ),
        ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildGlassChartCard(
          context,
          'Average Economy (${settings.fuelEconomyUnit.label})',
          Icons.speed_rounded,
          _AutoScaleBarChart(
            data: vehicleEconomies.entries.toList(),
            getLabel: (e) => e.key,
            getValue: (e) => e.value,
            valueSuffix: ' ${settings.fuelEconomyUnit.label}',
            xAxisLabel: 'Vehicle',
            yAxisLabel: 'Economy (${settings.fuelEconomyUnit.label})',
          ),
        ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildGlassChartCard(
          context,
          'Fuel Consumption (L)',
          Icons.local_gas_station_rounded,
          _AutoScaleBarChart(
            data: vehicleFuel.entries.toList(),
            getLabel: (e) => e.key,
            getValue: (e) => e.value,
            valueSuffix: ' L',
            xAxisLabel: 'Vehicle',
            yAxisLabel: 'Fuel (L)',
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
        const SizedBox(height: 16),
        _buildGlassChartCard(
          context,
          'Distance Traveled (${distanceUnit.label})',
          Icons.route_rounded,
          _AutoScaleBarChart(
            data: vehicleDistances.entries.toList(),
            getLabel: (e) => e.key,
            getValue: (e) => e.value,
            valueSuffix: ' ${distanceUnit.label}',
            xAxisLabel: 'Vehicle',
            yAxisLabel: 'Distance (${distanceUnit.label})',
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
        const SizedBox(height: 24),
        if (vehicleStats.values.any((v) => v.fillCount > 0)) ...[
          _buildDetailedComparisonTable(context, vehicleStats, distanceUnit).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
        ],
      ],
    );
  }

  Widget _buildGlassChartCard(BuildContext context, String title, IconData icon, Widget chart) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.5),
            context.cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.15 : 0.25),
          ],
        ),
        border: Border.all(
          color: context.cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: context.cs.shadow.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.cs.surface.withValues(alpha: 0.5),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            context.cs.primaryContainer.withValues(alpha: 0.5),
                            context.cs.secondaryContainer.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 22, color: context.cs.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: context.tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(height: 220, child: chart),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChartState(BuildContext context, String title, String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: context.cs.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: context.cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedComparisonTable(BuildContext context, Map<String, _VehicleStat> vehicleStats, DistanceUnit distanceUnit) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: context.cs.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 48,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 52,
            columnSpacing: 20,
            horizontalMargin: 16,
            headingTextStyle: context.tt.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.cs.primary,
            ),
            dataTextStyle: context.tt.bodySmall?.copyWith(
              color: context.cs.onSurface,
            ),
            columns: const [
              DataColumn(label: Text('Vehicle')),
              DataColumn(label: Text('Fills'), numeric: true),
              DataColumn(label: Text('Distance'), numeric: true),
              DataColumn(label: Text('Fuel (L)'), numeric: true),
              DataColumn(label: Text('Avg Economy'), numeric: true),
              DataColumn(label: Text('Fuel Cost'), numeric: true),
              DataColumn(label: Text('Service Cost'), numeric: true),
              DataColumn(label: Text('Total Cost'), numeric: true),
              DataColumn(label: Text('Cost/Dist'), numeric: true),
            ],
            rows: vehicleStats.entries.map((e) {
              final s = e.value;
              final costPerDist = s.distance > 0 ? s.totalCost / s.distance : 0.0;
              return DataRow(cells: [
                DataCell(Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(s.fillCount.toString())),
                DataCell(Text(formatDistance(s.distance, distanceUnit))),
                DataCell(Text(s.totalFuel.toStringAsFixed(1))),
                DataCell(Text(s.avgEconomy > 0 ? formatEconomy(s.avgEconomy, settings.fuelEconomyUnit) : '—')),
                DataCell(Text(formatCurrency(s.fuelCost, settings.currency))),
                DataCell(Text(formatCurrency(s.serviceCost, settings.currency))),
                DataCell(Text(formatCurrency(s.totalCost, settings.currency), style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(s.distance > 0 ? '${currencySymbol(settings.currency)}${costPerDist.toStringAsFixed(2)}/${distanceUnit.label}' : '—')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
class _BreathingStatCard extends StatefulWidget {
  const _BreathingStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.index,
  });

  final String label;
  final String value;
  final IconData icon;
  final int index;

  @override
  State<_BreathingStatCard> createState() => _BreathingStatCardState();
}

class _BreathingStatCardState extends State<_BreathingStatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Breathing animation that scales slightly
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.02), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    // Start with a delay based on index for staggered effect
    Future.delayed(Duration(milliseconds: widget.index * 150), () {
      if (mounted) {
        _breathingController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breathingController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {},
        child: SizedBox(
          width: 100,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.cs.primary.withValues(alpha: 0.1),
                      context.cs.secondary.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: context.cs.primary,
                ),
              ).animate().fadeIn(delay: (widget.index * 100).ms).scale(delay: (widget.index * 100).ms),
              const SizedBox(height: 8),
              Text(
                widget.value,
                style: context.tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: context.cs.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ).animate().fadeIn(delay: (widget.index * 100 + 50).ms),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: context.tt.labelSmall?.copyWith(
                  color: context.cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: (widget.index * 100 + 100).ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedChartChip extends StatefulWidget {
  const _AnimatedChartChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.index,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int index;

  @override
  State<_AnimatedChartChip> createState() => _AnimatedChartChipState();
}

class _AnimatedChartChipState extends State<_AnimatedChartChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? LinearGradient(
                    colors: [
                      context.cs.primary,
                      context.cs.primary.withValues(alpha: 0.8),
                    ],
                  )
                : LinearGradient(
                    colors: [
                      context.cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      context.cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    ],
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? context.cs.primary.withValues(alpha: 0.3)
                  : context.cs.outlineVariant.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: context.cs.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.icon,
                  key: ValueKey(widget.isSelected),
                  size: 20,
                  color: widget.isSelected ? context.cs.onPrimary : context.cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: context.tt.labelLarge?.copyWith(
                  color: widget.isSelected ? context.cs.onPrimary : context.cs.onSurface,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                ) ?? const TextStyle(),
                child: Text(widget.label),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (widget.index * 100).ms).slideX(begin: -0.2),
      ),
    );
  }
}

class _VehicleStat {
  final double totalCost;
  final double fuelCost;
  final double serviceCost;
  final double totalFuel;
  final double distance;
  final double avgEconomy;
  final int fillCount;

  _VehicleStat({
    required this.totalCost,
    required this.fuelCost,
    required this.serviceCost,
    required this.totalFuel,
    required this.distance,
    required this.avgEconomy,
    required this.fillCount,
  });
}

class _AutoScaleLineChart extends StatelessWidget {
  const _AutoScaleLineChart({
    required this.data,
    this.currency,
    this.xAxisLabel = '',
    this.yAxisLabel = '',
    required this.getXLabel,
    required this.getYLabel,
  });
  final List<MapEntry<double, double>> data;
  final String? currency;
  final String xAxisLabel;
  final String yAxisLabel;
  final String Function(int idx, List<MapEntry<double, double>> entries) getXLabel;
  final String Function(double value) getYLabel;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final minX = data.map((e) => e.key).reduce((a, b) => a < b ? a : b);
    final maxX = data.map((e) => e.key).reduce((a, b) => a > b ? a : b);
    final minY = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final padding = yRange > 0 ? yRange * 0.1 : (maxY * 0.1 + 1);

    // Calculate appropriate interval for x-axis to avoid label overlap
    final xInterval = data.length > 10 ? (data.length / 8).ceilToDouble() : 1.0;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80,
              interval: ((maxY - minY) / 5).clamp(0.1, double.infinity),
              getTitlesWidget: (value, _) => Text(
                getYLabel(value),
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            axisNameWidget: yAxisLabel.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(yAxisLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  )
                : null,
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: xInterval,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const Text('');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    getXLabel(idx, data),
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
            axisNameWidget: xAxisLabel.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(xAxisLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  )
                : null,
            axisNameSize: 20,
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: data.map((e) => FlSpot(e.key, e.value)).toList(),
            isCurved: true,
            color: context.cs.primary,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: context.cs.primary.withValues(alpha: 0.1)),
          ),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}

class _AutoScaleScatterChart extends StatelessWidget {
  const _AutoScaleScatterChart({
    required this.data,
    required this.xLabel,
    required this.yLabel,
  });
  final List<FlSpot> data;
  final String xLabel;
  final String yLabel;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));

    final minX = data.map((e) => e.x).reduce((a, b) => a < b ? a : b);
    final maxX = data.map((e) => e.x).reduce((a, b) => a > b ? a : b);
    final minY = data.map((e) => e.y).reduce((a, b) => a < b ? a : b);
    final maxY = data.map((e) => e.y).reduce((a, b) => a > b ? a : b);
    final xPadding = (maxX - minX) * 0.1 + 1;
    final yPadding = (maxY - minY) * 0.1 + 1;

    return ScatterChart(
      ScatterChartData(
        minX: minX - xPadding,
        maxX: maxX + xPadding,
        minY: minY - yPadding,
        maxY: maxY + yPadding,
        gridData: FlGridData(show: true, drawVerticalLine: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: ((maxY - minY) / 5).clamp(0.1, double.infinity),
              getTitlesWidget: (value, _) => Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 10)),
            ),
            axisNameWidget: Text(yLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: (maxX - minX) / 5,
              getTitlesWidget: (value, _) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10)),
              ),
            ),
            axisNameWidget: Text(xLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            axisNameSize: 20,
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        scatterSpots: data.map((spot) => ScatterSpot(spot.x, spot.y)).toList(),
      ),
    );
  }
}

class _AutoScaleBarChart extends StatelessWidget {
  const _AutoScaleBarChart({
    required this.data,
    required this.getLabel,
    required this.getValue,
    this.currency,
    this.valueSuffix = '',
    this.showValue = false,
    this.xAxisLabel = '',
    this.yAxisLabel = '',
  });
  final List<MapEntry<String, double>> data;
  final String Function(MapEntry<String, double> entry) getLabel;
  final double Function(MapEntry<String, double> entry) getValue;
  final String? currency;
  final String valueSuffix;
  final bool showValue;
  final String xAxisLabel;
  final String yAxisLabel;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('No data'));

    final maxY = data.map((e) => getValue(e)).reduce((a, b) => a > b ? a : b);
    final padding = maxY * 0.2 + 1;

    return BarChart(
      BarChartData(
        maxY: maxY + padding,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80,
              interval: (maxY / 5).clamp(0.1, double.infinity),
              getTitlesWidget: (value, _) {
                final prefix = currency != null ? currencySymbol(currency!) : '';
                return Text('$prefix${value.toStringAsFixed(0)}$valueSuffix', style: const TextStyle(fontSize: 10));
              },
            ),
            axisNameWidget: yAxisLabel.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(yAxisLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  )
                : null,
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const Text('');
                return SideTitleWidget(
                  axisSide: AxisSide.bottom,
                  space: 4,
                  child: Text(getLabel(data[idx]), style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                );
              },
            ),
            axisNameWidget: xAxisLabel.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(xAxisLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                  )
                : null,
            axisNameSize: 20,
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: getValue(e.value),
                color: context.cs.primary,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
            showingTooltipIndicators: [0],
          );
        }).toList(),
        barTouchData: BarTouchData(
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}

class BarSeries {
  final String name;
  final List<double> values;
  final Color color;
  BarSeries(this.name, this.values, this.color);
}

class _GroupedBarChart extends StatelessWidget {
  const _GroupedBarChart({
    required this.labels,
    required this.series,
    required this.currency,
  });
  final List<String> labels;
  final List<BarSeries> series;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || series.isEmpty) return const Center(child: Text('No data'));

    final maxY = series.expand((s) => s.values).reduce((a, b) => a > b ? a : b);
    final padding = maxY * 0.2 + 1;
    final barWidth = 16 / series.length;

    return BarChart(
      BarChartData(
        maxY: maxY + padding,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80,
              interval: (maxY / 5).clamp(0.1, double.infinity),
              getTitlesWidget: (value, _) => Text('${currencySymbol(currency)}${value.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10)),
            ),
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Cost', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ),
            axisNameSize: 20,
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const Text('');
                return SideTitleWidget(
                  axisSide: AxisSide.bottom,
                  space: 4,
                  child: Text(labels[idx], style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                );
              },
            ),
            axisNameWidget: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Vehicle', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            ),
            axisNameSize: 20,
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(labels.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: series.asMap().entries.map((s) {
              return BarChartRodData(
                toY: s.value.values[i],
                color: s.value.color,
                width: barWidth,
                borderRadius: BorderRadius.circular(2),
              );
            }).toList(),
            showingTooltipIndicators: [0],
          );
        }),
        barTouchData: BarTouchData(
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}

class _ExpensePieChart extends StatelessWidget {
  const _ExpensePieChart({
    required this.data,
    required this.currency,
  });
  final Map<String, double> data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final total = entries.fold(0.0, (a, b) => a + b.value);

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((e) {
          final value = e.value.value;
          final percentage = total > 0 ? (value / total * 100) : 0;
          return PieChartSectionData(
            value: value,
            title: '${percentage.toStringAsFixed(1)}%',
            color: _colorForIndex(e.key),
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {},
          enabled: true,
        ),
      ),
    );
  }

  Color _colorForIndex(int i) {
    const colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.red,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    ];
    return colors[i % colors.length];
  }
}

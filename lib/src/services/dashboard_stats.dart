import '../models/fuel_record.dart';
import '../models/record.dart';
import '../models/vehicle.dart';
import '../models/app_settings.dart';
import '../models/reminder.dart';
import '../services/fuel_stats.dart';

class DashboardStats {
  const DashboardStats({
    required this.vehicleCount,
    required this.totalFuelEntries,
    required this.totalServiceEntries,
    required this.totalFuelCost,
    required this.totalServiceCost,
    required this.totalOdometer,
    required this.averageEconomy,
    required this.bestEconomy,
    required this.latestEconomy,
    required this.fuelCostByMonth,
    required this.economyBySegment,
    required this.expensesByCategory,
    required this.upcomingReminders,
  });

  final int vehicleCount;
  final int totalFuelEntries;
  final int totalServiceEntries;
  final double totalFuelCost;
  final double totalServiceCost;
  final double totalOdometer;
  final double averageEconomy;
  final double bestEconomy;
  final double? latestEconomy;
  final Map<String, double> fuelCostByMonth;
  final List<double> economyBySegment;
  final Map<String, double> expensesByCategory;
  final int upcomingReminders;
}

DashboardStats computeDashboardStats({
  required List<Vehicle> vehicles,
  required List<FuelRecord> allFuelRecords,
  required List<Record> allRecords,
  required List<Reminder> allReminders,
  required AppSettings settings,
}) {
  int totalFuelEntries = 0;
  int totalServiceEntries = 0;
  double totalFuelCost = 0;
  double totalServiceCost = 0;
  double totalOdometer = 0;
  final fuelCostByMonth = <String, double>{};
  final economyBySegment = <double>[];
  final expensesByCategory = <String, double>{};
  int upcomingReminders = 0;

  for (final v in vehicles) {
    totalOdometer += v.currentOdometer;

    final vFuels = allFuelRecords.where((f) => f.vehicleId == v.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final vRecords = allRecords.where((r) => r.vehicleId == v.id).toList();

    totalFuelEntries += vFuels.length;
    totalServiceEntries += vRecords.length;

    for (final f in vFuels) {
      totalFuelCost += f.totalCost;
      final monthKey = '${f.date.year}-${f.date.month.toString().padLeft(2, '0')}';
      fuelCostByMonth[monthKey] = (fuelCostByMonth[monthKey] ?? 0) + f.totalCost;
    }

    for (final r in vRecords) {
      totalServiceCost += r.cost ?? 0;
      final cat = r.type.label;
      expensesByCategory[cat] = (expensesByCategory[cat] ?? 0) + (r.cost ?? 0);
    }

    if (vFuels.length >= 2) {
      final stats = computeFuelStats(vFuels, settings);
      if (stats.averageKmPerLiter > 0) economyBySegment.add(stats.averageKmPerLiter);
      if (stats.bestKmPerLiter > 0) economyBySegment.add(stats.bestKmPerLiter);
      if (stats.latestSegment?.kmPerLiter != null && stats.latestSegment!.kmPerLiter > 0) {
        economyBySegment.add(stats.latestSegment!.kmPerLiter);
      }
    }
  }

  double averageEconomy = 0;
  double bestEconomy = 0;
  double? latestEconomy;
  if (economyBySegment.isNotEmpty) {
    averageEconomy = economyBySegment.reduce((a, b) => a + b) / economyBySegment.length;
    bestEconomy = economyBySegment.reduce((a, b) => a > b ? a : b);
    latestEconomy = economyBySegment.last;
  }

  final now = DateTime.now();
  for (final r in allReminders) {
    if (r.enabled &&
        (r.state == ReminderState.upcoming ||
         r.state == ReminderState.due ||
         r.state == ReminderState.overdue)) {
      upcomingReminders++;
    }
  }

  return DashboardStats(
    vehicleCount: vehicles.length,
    totalFuelEntries: totalFuelEntries,
    totalServiceEntries: totalServiceEntries,
    totalFuelCost: totalFuelCost,
    totalServiceCost: totalServiceCost,
    totalOdometer: totalOdometer,
    averageEconomy: averageEconomy,
    bestEconomy: bestEconomy,
    latestEconomy: latestEconomy,
    fuelCostByMonth: fuelCostByMonth,
    economyBySegment: economyBySegment,
    expensesByCategory: expensesByCategory,
    upcomingReminders: upcomingReminders,
  );
}
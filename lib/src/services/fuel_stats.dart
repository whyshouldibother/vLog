import '../models/fuel_record.dart';
import '../models/app_settings.dart';
import '../utils/units.dart';

/// Segment of a fuel fill: km driven and litres used between two consecutive fills.
class MileageSegment {
  const MileageSegment({
    required this.date,
    required this.odometerStart,
    required this.odometerEnd,
    required this.kmDriven,
    required this.litersUsed,
    required this.totalCost,
    required this.valid,
  });

  final DateTime date;
  final double odometerStart;
  final double odometerEnd;
  final double kmDriven;
  final double litersUsed;
  final double totalCost;
  final bool valid; // true if kmDriven > 0 && litersUsed > 0

  double get kmPerLiter => valid && litersUsed > 0 ? kmDriven / litersUsed : 0;
  double get costPerKm => valid && kmDriven > 0 ? totalCost / kmDriven : 0.0;
}

/// Aggregated fuel statistics from a list of [FuelRecord]s, sorted by date.
class FuelStats {
  const FuelStats({
    required this.segments,
    required this.totalKm,
    required this.totalLiters,
    required this.averageKmPerLiter,
    required this.bestKmPerLiter,
    required this.latestSegment,
    required this.firstOdometer,
    required this.lastOdometer,
    required this.recordCount,
  });

  final List<MileageSegment> segments;
  final double totalKm;
  final double totalLiters;
  final double averageKmPerLiter;
  final double bestKmPerLiter;
  final MileageSegment? latestSegment;
  final double firstOdometer;
  final double lastOdometer;
  final int recordCount;

  /// Convert economy to the requested [FuelEconomyUnit] using [AppSettings].
  String economyString(double kmPerLiter, FuelEconomyUnit unit) {
    final value = economyFromKmPerLiter(kmPerLiter, unit);
    return '${value.toStringAsFixed(2)} ${unit.label}';
  }

  String averageEconomyString(FuelEconomyUnit unit) =>
      economyString(averageKmPerLiter, unit);

  String bestEconomyString(FuelEconomyUnit unit) =>
      economyString(bestKmPerLiter, unit);

  String? latestEconomyString(FuelEconomyUnit unit) =>
      latestSegment != null ? economyString(latestSegment!.kmPerLiter, unit) : null;
}

/// Build [MileageSegment]s from [FuelRecord]s sorted by [date].
/// Segments with non-positive km or litres are marked invalid.
List<MileageSegment> buildSegments(List<FuelRecord> records) {
  final sorted = records..sort((a, b) => a.date.compareTo(b.date));
  final segments = <MileageSegment>[];
  for (int i = 1; i < sorted.length; i++) {
    final prev = sorted[i - 1];
    final curr = sorted[i];
    final km = curr.odometer - prev.odometer;
    final liters = curr.quantity;
    segments.add(MileageSegment(
      date: curr.date,
      odometerStart: prev.odometer,
      odometerEnd: curr.odometer,
      kmDriven: km,
      litersUsed: liters,
      totalCost: curr.totalCost,
      valid: km > 0 && liters > 0,
    ));
  }
  return segments;
}

/// Compute [FuelStats] from [FuelRecord]s.
FuelStats computeFuelStats(List<FuelRecord> records, AppSettings settings) {
  final segments = buildSegments(records);
  final totalKm = segments.fold(0.0, (sum, s) => sum + s.kmDriven);
  final totalLiters = segments.fold(0.0, (sum, s) => sum + s.litersUsed);
  final avgKmPerLiter = totalLiters > 0 ? totalKm / totalLiters : 0.0;
  final bestKmPerLiter =
      segments.isNotEmpty
          ? segments.map((s) => s.kmPerLiter).reduce((a, b) => a > b ? a : b)
          : 0.0;
  final latestSeg = segments.isNotEmpty ? segments.last : null;
  final firstOdometer = records.isNotEmpty ? records.first.odometer : 0.0;
  final lastOdometer = records.isNotEmpty ? records.last.odometer : 0.0;
  return FuelStats(
    segments: segments,
    totalKm: totalKm,
    totalLiters: totalLiters,
    averageKmPerLiter: avgKmPerLiter,
    bestKmPerLiter: bestKmPerLiter,
    latestSegment: latestSeg,
    firstOdometer: firstOdometer,
    lastOdometer: lastOdometer,
    recordCount: records.length,
  );
}
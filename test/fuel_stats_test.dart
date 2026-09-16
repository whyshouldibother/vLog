import 'package:flutter_test/flutter_test.dart';
import 'package:vlog/src/models/fuel_record.dart';
import 'package:vlog/src/models/app_settings.dart';
import 'package:vlog/src/services/fuel_stats.dart';

void main() {
  group('MileageSegment', () {
    test('valid segment has positive km and liters', () {
      final seg = MileageSegment(
        date: DateTime(2026, 1, 2),
        odometerStart: 10000,
        odometerEnd: 10500,
        kmDriven: 500,
        litersUsed: 40,
        totalCost: 6000,
        valid: true,
      );
      expect(seg.valid, isTrue);
      expect(seg.kmPerLiter, equals(12.5));
    });

    test('invalid segment when km is zero', () {
      final seg = MileageSegment(
        date: DateTime(2026, 1, 2),
        odometerStart: 10000,
        odometerEnd: 10000,
        kmDriven: 0,
        litersUsed: 40,
        totalCost: 0,
        valid: false,
      );
      expect(seg.valid, isFalse);
    });

    test('invalid segment when liters is zero', () {
      final seg = MileageSegment(
        date: DateTime(2026, 1, 2),
        odometerStart: 10000,
        odometerEnd: 10500,
        kmDriven: 500,
        litersUsed: 0,
        totalCost: 0,
        valid: false,
      );
      expect(seg.valid, isFalse);
    });
  });

  group('buildSegments', () {
    test('builds segments from sorted records', () {
      final records = [
        FuelRecord(
          id: '1',
          vehicleId: 'v1',
          date: DateTime(2026, 1, 1),
          odometer: 10000,
          quantity: 40,
          pricePerUnit: 150,
          totalCost: 6000,
          currency: 'NPR',
          fuelType: '',
          station: '',
          notes: '',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        FuelRecord(
          id: '2',
          vehicleId: 'v1',
          date: DateTime(2026, 1, 5),
          odometer: 10500,
          quantity: 30,
          pricePerUnit: 160,
          totalCost: 4800,
          currency: 'NPR',
          fuelType: '',
          station: '',
          notes: '',
          createdAt: DateTime(2026, 1, 5),
          updatedAt: DateTime(2026, 1, 5),
        ),
      ];
      final segments = buildSegments(records);
      expect(segments, hasLength(1));
      expect(segments.first.kmDriven, equals(500));
      expect(segments.first.litersUsed, equals(30));
      expect(segments.first.valid, isTrue);
    });

    test('handles single record → no segments', () {
      final records = [FuelRecord(
        id: '1',
        vehicleId: 'v1',
        date: DateTime(2026, 1, 1),
        odometer: 10000,
        quantity: 40,
        pricePerUnit: 150,
        totalCost: 6000,
        currency: 'NPR',
        fuelType: '',
        station: '',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      )];
      final segments = buildSegments(records);
      expect(segments, isEmpty);
    });
  });

  group('computeFuelStats', () {
    test('empty records → zero stats', () {
      final stats = computeFuelStats(<FuelRecord>[], AppSettings());
      expect(stats.recordCount, equals(0));
      expect(stats.totalKm, equals(0.0));
      expect(stats.totalLiters, equals(0.0));
      expect(stats.averageKmPerLiter, equals(0.0));
      expect(stats.bestKmPerLiter, equals(0.0));
    });

    test('two records with invalid fill (decreasing fuel)', () {
      final records = [
        FuelRecord(
          id: '1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
          odometer: 10000, quantity: 40,
          pricePerUnit: 150, totalCost: 6000,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
        FuelRecord(
          id: '2', vehicleId: 'v1', date: DateTime(2026, 1, 5),
          odometer: 10500, quantity: 30,
          pricePerUnit: 160, totalCost: 4800,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 5), updatedAt: DateTime(2026, 1, 5),
        ),
      ];
      final stats = computeFuelStats(records, AppSettings());
      expect(stats.recordCount, equals(2));
      expect(stats.totalKm, equals(500));
      expect(stats.totalLiters, equals(30));
      expect(stats.averageKmPerLiter, closeTo(16.67, 0.01));
      expect(stats.bestKmPerLiter, closeTo(16.67, 0.01));
    });

    test('decreasing odometer → invalid segment', () {
      final records = [
        FuelRecord(
          id: '2', vehicleId: 'v1', date: DateTime(2026, 1, 5),
          odometer: 10000, quantity: 30,
          pricePerUnit: 160, totalCost: 4800,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 5), updatedAt: DateTime(2026, 1, 5),
        ),
        FuelRecord(
          id: '1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
          odometer: 10500, quantity: 40,
          pricePerUnit: 150, totalCost: 6000,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
      ];
      final stats = computeFuelStats(records, AppSettings());
      expect(stats.segments.first.valid, isFalse);
    });

    test('multi-vehicle records mixed', () {
      final records = [
        FuelRecord(
          id: '1', vehicleId: 'v1', date: DateTime(2026, 1, 1),
          odometer: 10000, quantity: 40,
          pricePerUnit: 150, totalCost: 6000,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 1), updatedAt: DateTime(2026, 1, 1),
        ),
        FuelRecord(
          id: '2', vehicleId: 'v2', date: DateTime(2026, 1, 5),
          odometer: 20000, quantity: 50,
          pricePerUnit: 160, totalCost: 8000,
          currency: 'NPR', fuelType: '', station: '',
          notes: '', createdAt: DateTime(2026, 1, 5), updatedAt: DateTime(2026, 1, 5),
        ),
      ];
      final stats = computeFuelStats(records, AppSettings());
      expect(stats.recordCount, equals(2));
      expect(stats.segments, hasLength(1));
    });
  });
}
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fuel_record.freezed.dart';
part 'fuel_record.g.dart';

@freezed
class FuelRecord with _$FuelRecord {
  const factory FuelRecord({
    required String id,
    required String vehicleId,
    required DateTime date,
    required double odometer,
    required double quantity,
    required double pricePerUnit,
    required double totalCost,
    @Default('NPR') String currency,
    @Default('') String fuelType,
    @Default('') String station,
    @Default('') String notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _FuelRecord;

  factory FuelRecord.fromJson(Map<String, dynamic> json) =>
      _$FuelRecordFromJson(json);
}

extension FuelRecordX on FuelRecord {
  Map<String, Object?> toDbMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'quantity': quantity,
        'price_per_unit': pricePerUnit,
        'total_cost': totalCost,
        'currency': currency,
        'fuel_type': fuelType,
        'station': station,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

FuelRecord fuelRecordFromDbMap(Map<String, Object?> map) => FuelRecord(
      id: map['id'] as String,
      vehicleId: map['vehicle_id'] as String,
      date: DateTime.parse(map['date'] as String),
      odometer: (map['odometer'] as num).toDouble(),
      quantity: (map['quantity'] as num).toDouble(),
      pricePerUnit: (map['price_per_unit'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'NPR',
      fuelType: (map['fuel_type'] as String?) ?? '',
      station: (map['station'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
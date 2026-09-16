import 'package:freezed_annotation/freezed_annotation.dart';

part 'vehicle.freezed.dart';
part 'vehicle.g.dart';

@freezed
class Vehicle with _$Vehicle {
  const factory Vehicle({
    required String id,
    @Default('') String name,
    @Default('') String registrationNumber,
    @Default('') String make,
    @Default('') String model,
    @Default('') String variant,
    int? year,
    @Default('') String vin,
    @Default('') String engineNumber,
    @Default('') String fuelType,
    @Default(0) double currentOdometer,
    @Default('') String notes,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Vehicle;

  factory Vehicle.fromJson(Map<String, dynamic> json) => _$VehicleFromJson(json);
}

extension VehicleX on Vehicle {
  String get displayName {
    final label = [make, model].where((e) => e.trim().isNotEmpty).join(' ');
    if (name.trim().isNotEmpty) return name.trim();
    if (label.isNotEmpty) return label;
    if (registrationNumber.trim().isNotEmpty) return registrationNumber.trim();
    return 'Vehicle';
  }
}

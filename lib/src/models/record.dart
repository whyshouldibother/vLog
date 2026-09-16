import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'record.freezed.dart';
part 'record.g.dart';

@freezed
class Record with _$Record {
  const factory Record({
    required String id,
    required String vehicleId,
    required RecordType type,
    required DateTime date,
    double? odometer,
    double? cost,
    @Default('NPR') String currency,
    @Default('') String provider,
    @Default('') String title,
    @Default('') String description,
    @Default('') String notes,
    @Default({}) Map<String, dynamic> details,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Record;

  factory Record.fromJson(Map<String, dynamic> json) =>
      _$RecordFromJson(json);
}

extension RecordX on Record {
  Map<String, Object?> toDbMap() => {
        'id': id,
        'vehicle_id': vehicleId,
        'type': type.name,
        'date': date.toIso8601String(),
        'odometer': odometer,
        'cost': cost,
        'currency': currency,
        'provider': provider,
        'title': title,
        'description': description,
        'notes': notes,
        'details': jsonEncode(details),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

Record recordFromDbMap(Map<String, Object?> map) {
  final detailsStr = map['details'] as String?;
  return Record(
    id: map['id'] as String,
    vehicleId: map['vehicle_id'] as String,
    type: RecordType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RecordType.customEvent),
    date: DateTime.parse(map['date'] as String),
    odometer: (map['odometer'] as num?)?.toDouble(),
    cost: (map['cost'] as num?)?.toDouble(),
    currency: (map['currency'] as String?) ?? 'NPR',
    provider: (map['provider'] as String?) ?? '',
    title: (map['title'] as String?) ?? '',
    description: (map['description'] as String?) ?? '',
    notes: (map['notes'] as String?) ?? '',
    details: detailsStr != null && detailsStr.isNotEmpty
        ? Map<String, dynamic>.from(
            const JsonDecoder().convert(detailsStr) as Map)
        : {},
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}

enum RecordType {
  oilChange,
  oilFilter,
  airFilter,
  cabinFilter,
  fuelFilter,
  brakePads,
  brakeFluid,
  coolant,
  transmissionFluid,
  differentialFluid,
  sparkPlugs,
  battery,
  tires,
  alignment,
  suspension,
  ac,
  wipers,
  belts,
  generalService,
  repair,
  inspection,
  registration,
  insurance,
  warranty,
  customEvent,
}

extension RecordTypeX on RecordType {
  String get label {
    switch (this) {
      case RecordType.oilChange:
        return 'Oil change';
      case RecordType.oilFilter:
        return 'Oil filter';
      case RecordType.airFilter:
        return 'Air filter';
      case RecordType.cabinFilter:
        return 'Cabin filter';
      case RecordType.fuelFilter:
        return 'Fuel filter';
      case RecordType.brakePads:
        return 'Brake pads';
      case RecordType.brakeFluid:
        return 'Brake fluid';
      case RecordType.coolant:
        return 'Coolant';
      case RecordType.transmissionFluid:
        return 'Transmission fluid';
      case RecordType.differentialFluid:
        return 'Differential fluid';
      case RecordType.sparkPlugs:
        return 'Spark plugs';
      case RecordType.battery:
        return 'Battery';
      case RecordType.tires:
        return 'Tires';
      case RecordType.alignment:
        return 'Alignment';
      case RecordType.suspension:
        return 'Suspension';
      case RecordType.ac:
        return 'AC';
      case RecordType.wipers:
        return 'Wipers';
      case RecordType.belts:
        return 'Belts';
      case RecordType.generalService:
        return 'General service';
      case RecordType.repair:
        return 'Repair';
      case RecordType.inspection:
        return 'Inspection';
      case RecordType.registration:
        return 'Registration';
      case RecordType.insurance:
        return 'Insurance';
      case RecordType.warranty:
        return 'Warranty';
      case RecordType.customEvent:
        return 'Custom event';
    }
  }

  IconData get icon {
    switch (this) {
      case RecordType.repair:
        return Icons.handyman_outlined;
      case RecordType.inspection:
        return Icons.checklist_outlined;
      case RecordType.registration:
        return Icons.description_outlined;
      case RecordType.insurance:
        return Icons.shield_outlined;
      case RecordType.warranty:
        return Icons.verified_outlined;
      case RecordType.oilChange:
        return Icons.oil_barrel_outlined;
      case RecordType.oilFilter:
        return Icons.oil_barrel_outlined;
      case RecordType.battery:
        return Icons.battery_charging_full;
      case RecordType.tires:
        return Icons.circle_outlined;
      case RecordType.belts:
        return Icons.swap_horiz;
      case RecordType.airFilter:
      case RecordType.cabinFilter:
      case RecordType.fuelFilter:
        return Icons.air_outlined;
      case RecordType.sparkPlugs:
        return Icons.flash_on;
      default:
        return Icons.build_outlined;
    }
  }
}
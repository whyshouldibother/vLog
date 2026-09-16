import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

enum AppThemeMode { system, light, dark }

enum DistanceUnit { km, mile }

enum VolumeUnit { liter, gallonUs, gallonUk }

enum FuelEconomyUnit { kmPerLiter, literPer100Km, mpg }

enum OdometerEntryMode { absolute, relative }

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(AppThemeMode.system) AppThemeMode themeMode,
    @Default('NPR') String currency,
    @Default(DistanceUnit.km) DistanceUnit distanceUnit,
    @Default(VolumeUnit.liter) VolumeUnit volumeUnit,
    @Default(FuelEconomyUnit.kmPerLiter) FuelEconomyUnit fuelEconomyUnit,
    @Default('dd/MM/yyyy') String dateFormat,
    @Default(OdometerEntryMode.absolute) OdometerEntryMode odometerEntryMode,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

const List<String> kCurrencies = ['NPR', 'USD', 'EUR', 'GBP', 'INR'];

const List<String> kDateFormats = [
  'dd/MM/yyyy',
  'MM/dd/yyyy',
  'yyyy-MM-dd',
  'dd MMM yyyy',
  'MMM dd, yyyy',
];

extension DistanceUnitX on DistanceUnit {
  String get label => this == DistanceUnit.km ? 'km' : 'mi';
}

extension VolumeUnitX on VolumeUnit {
  String get label {
    switch (this) {
      case VolumeUnit.liter:
        return 'L';
      case VolumeUnit.gallonUs:
        return 'gal (US)';
      case VolumeUnit.gallonUk:
        return 'gal (UK)';
    }
  }
}

extension FuelEconomyUnitX on FuelEconomyUnit {
  String get label {
    switch (this) {
      case FuelEconomyUnit.kmPerLiter:
        return 'km/L';
      case FuelEconomyUnit.literPer100Km:
        return 'L/100 km';
      case FuelEconomyUnit.mpg:
        return 'MPG';
    }
  }
}

extension OdometerEntryModeX on OdometerEntryMode {
  String get label {
    switch (this) {
      case OdometerEntryMode.absolute:
        return 'Absolute (Odometer Reading)';
      case OdometerEntryMode.relative:
        return 'Relative (Distance Since Last)';
    }
  }

  String get shortLabel {
    switch (this) {
      case OdometerEntryMode.absolute:
        return 'Absolute';
      case OdometerEntryMode.relative:
        return 'Relative';
    }
  }
}

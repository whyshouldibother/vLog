import '../models/app_settings.dart';

/// Unit conversions. Internally all distance is km and all volume is litres.
const double _kmPerMile = 1.609344;
const double _litersPerUsGallon = 3.785411784;
const double _litersPerUkGallon = 4.54609;

double mileToKm(double miles) => miles * _kmPerMile;
double kmToMile(double km) => km / _kmPerMile;

double usGallonToLiters(double gal) => gal * _litersPerUsGallon;
double ukGallonToLiters(double gal) => gal * _litersPerUkGallon;
double litersToUsGallon(double l) => l / _litersPerUsGallon;
double litersToUkGallon(double l) => l / _litersPerUkGallon;

double convertDistance(double value, DistanceUnit from, DistanceUnit to) {
  if (from == to) return value;
  return from == DistanceUnit.km ? kmToMile(value) : mileToKm(value);
}

double convertVolume(double value, VolumeUnit from, VolumeUnit to) {
  if (from == to) return value;
  final liters = from == VolumeUnit.liter ? value : _volumeToLiters(value, from);
  return _litersToVolume(liters, to);
}

double _volumeToLiters(double value, VolumeUnit unit) {
  switch (unit) {
    case VolumeUnit.liter:
      return value;
    case VolumeUnit.gallonUs:
      return usGallonToLiters(value);
    case VolumeUnit.gallonUk:
      return ukGallonToLiters(value);
  }
}

double _litersToVolume(double liters, VolumeUnit unit) {
  switch (unit) {
    case VolumeUnit.liter:
      return liters;
    case VolumeUnit.gallonUs:
      return litersToUsGallon(liters);
    case VolumeUnit.gallonUk:
      return litersToUkGallon(liters);
  }
}

/// Converts a distance-per-volume economy value ([km] / [liters]) into the
/// requested display unit.
double economyFromKmPerLiter(double kmPerLiter, FuelEconomyUnit unit) {
  switch (unit) {
    case FuelEconomyUnit.kmPerLiter:
      return kmPerLiter;
    case FuelEconomyUnit.literPer100Km:
      return kmPerLiter > 0 ? 100 / kmPerLiter : 0;
    case FuelEconomyUnit.mpg:
      return kmPerLiter * 2.352145833;
  }
}

double formatDistanceValue(double km, DistanceUnit unit) =>
    convertDistance(km, DistanceUnit.km, unit);

String formatDistance(double km, DistanceUnit unit) {
  final value = convertDistance(km, DistanceUnit.km, unit);
  return '${value.toStringAsFixed(value.abs() >= 100 ? 0 : 1)} ${unit.label}';
}

String formatVolume(double liters, VolumeUnit unit) {
  final value = convertVolume(liters, VolumeUnit.liter, unit);
  return '${value.toStringAsFixed(2)} ${unit.label}';
}

String formatEconomy(double kmPerLiter, FuelEconomyUnit unit) {
  if (kmPerLiter <= 0) return '—';
  final value = economyFromKmPerLiter(kmPerLiter, unit);
  return '${value.toStringAsFixed(2)} ${unit.label}';
}

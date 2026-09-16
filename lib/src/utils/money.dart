/// Monetary helpers. Amounts are stored as [double] and rounded to two minor
/// units on write to avoid drift from repeated floating point input.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

double? parseMoney(String? input) {
  if (input == null) return null;
  final cleaned = input.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

const Map<String, String> _currencySymbols = {
  'NPR': 'Rs ',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
};

String currencySymbol(String currency) => _currencySymbols[currency] ?? '$currency ';

String formatCurrency(double? value, String currency, {int decimals = 2}) {
  if (value == null) return '—';
  return '${currencySymbol(currency)}${value.toStringAsFixed(decimals)}';
}

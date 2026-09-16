import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';
import '../providers/providers.dart';
import '../repository/vehicle_repository.dart';

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _registration;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _variant;
  late final TextEditingController _year;
  late final TextEditingController _vin;
  late final TextEditingController _engineNumber;
  late final TextEditingController _fuelType;
  late final TextEditingController _odometer;
  late final TextEditingController _notes;
  bool _saving = false;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    _name = TextEditingController(text: v?.name ?? '');
    _registration = TextEditingController(text: v?.registrationNumber ?? '');
    _make = TextEditingController(text: v?.make ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _variant = TextEditingController(text: v?.variant ?? '');
    _year = TextEditingController(text: v?.year?.toString() ?? '');
    _vin = TextEditingController(text: v?.vin ?? '');
    _engineNumber = TextEditingController(text: v?.engineNumber ?? '');
    _fuelType = TextEditingController(text: v?.fuelType ?? '');
    _odometer = TextEditingController(
        text: v == null || v.currentOdometer == 0
            ? ''
            : v.currentOdometer.toStringAsFixed(0));
    _notes = TextEditingController(text: v?.notes ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _registration,
      _make,
      _model,
      _variant,
      _year,
      _vin,
      _engineNumber,
      _fuelType,
      _odometer,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final odometer = double.tryParse(_odometer.text.trim()) ?? 0;
    final year = int.tryParse(_year.text.trim());
    final vehicle = Vehicle(
      id: widget.vehicle?.id ?? VehicleRepository.newId(),
      name: _name.text.trim(),
      registrationNumber: _registration.text.trim(),
      make: _make.text.trim(),
      model: _model.text.trim(),
      variant: _variant.text.trim(),
      year: year,
      vin: _vin.text.trim(),
      engineNumber: _engineNumber.text.trim(),
      fuelType: _fuelType.text.trim(),
      currentOdometer: odometer,
      notes: _notes.text.trim(),
      createdAt: widget.vehicle?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final notifier = ref.read(vehiclesNotifierProvider.notifier);
      if (_isEditing) {
        await notifier.updateVehicle(vehicle);
      } else {
        await notifier.addVehicle(vehicle);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit vehicle' : 'Add vehicle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Name / nickname'),
            _field(_registration, 'Registration number'),
            _field(_make, 'Make'),
            _field(_model, 'Model'),
            _field(_variant, 'Variant'),
            _field(_year, 'Year',
                keyboardType: TextInputType.number,
                validator: _validateYear),
            _field(_vin, 'VIN / chassis number'),
            _field(_engineNumber, 'Engine number'),
            _field(_fuelType, 'Fuel type'),
            _field(_odometer, 'Current odometer',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validateOdometer),
            _field(_notes, 'Notes', maxLines: 3),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEditing ? 'Save changes' : 'Add vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  String? _validateYear(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final year = int.tryParse(value.trim());
    if (year == null || year < 1900 || year > 2200) return 'Enter a valid year';
    return null;
  }

  String? _validateOdometer(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final odo = double.tryParse(value.trim());
    if (odo == null || odo < 0) return 'Odometer cannot be negative';
    return null;
  }
}

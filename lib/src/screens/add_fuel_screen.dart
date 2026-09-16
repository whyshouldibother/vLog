import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/fuel_record.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/money.dart';

class AddFuelScreen extends ConsumerStatefulWidget {
  const AddFuelScreen({
    super.key,
    required this.vehicleId,
    this.initialRecord,
  });
  final String vehicleId;
  final FuelRecord? initialRecord;

  @override
  ConsumerState<AddFuelScreen> createState() => _AddFuelScreenState();
}

class _AddFuelScreenState extends ConsumerState<AddFuelScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  final _odometerCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _fuelTypeCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;
  bool get _isEditing => widget.initialRecord != null;
  double? _lastOdometer;
  bool _useRelativeMode = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecord;
    _date = r?.date ?? DateTime.now();
    if (r != null) {
      _odometerCtrl.text = r.odometer.toStringAsFixed(1);
      _quantityCtrl.text = r.quantity.toStringAsFixed(2);
      _priceCtrl.text = r.pricePerUnit.toStringAsFixed(2);
      _totalCtrl.text = r.totalCost.toStringAsFixed(2);
      _fuelTypeCtrl.text = r.fuelType;
      _stationCtrl.text = r.station;
      _notesCtrl.text = r.notes;
    }
    _loadLastOdometer();
  }

  Future<void> _loadLastOdometer() async {
    if (_isEditing) return;
    final records = await ref.read(fuelRepositoryProvider).getByVehicle(widget.vehicleId);
    if (records.isNotEmpty) {
      records.sort((a, b) => b.date.compareTo(a.date));
      _lastOdometer = records.first.odometer;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    for (final c in [
      _odometerCtrl, _quantityCtrl, _priceCtrl, _totalCtrl,
      _fuelTypeCtrl, _stationCtrl, _notesCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final qty = double.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final currency = ref.read(appSettingsNotifierProvider).value?.currency ?? 'NPR';
    
    double odometer;
    if (_useRelativeMode && _lastOdometer != null) {
      final relative = double.tryParse(_odometerCtrl.text) ?? 0;
      odometer = _lastOdometer! + relative;
    } else {
      odometer = double.tryParse(_odometerCtrl.text) ?? 0;
    }

    final record = FuelRecord(
      id: _isEditing ? widget.initialRecord!.id : const Uuid().v4(),
      vehicleId: widget.vehicleId,
      date: _date,
      odometer: odometer,
      quantity: qty,
      pricePerUnit: price,
      totalCost: roundMoney(double.tryParse(_totalCtrl.text) ?? qty * price),
      currency: currency,
      fuelType: _fuelTypeCtrl.text.trim(),
      station: _stationCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdAt: _isEditing ? widget.initialRecord!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      if (_isEditing) {
        await ref.read(fuelRepositoryProvider).update(record);
      } else {
        await ref.read(fuelRepositoryProvider).create(record);
      }
      ref.invalidate(fuelRecordsProvider(widget.vehicleId));
      ref.invalidate(vehiclesNotifierProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete fuel entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || _isEditing == false) return;
    try {
      await ref.read(fuelRepositoryProvider).delete(widget.initialRecord!.id);
      ref.invalidate(fuelRecordsProvider(widget.vehicleId));
      ref.invalidate(vehiclesNotifierProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _toggleOdometerMode() {
    setState(() {
      _useRelativeMode = !_useRelativeMode;
      if (_useRelativeMode && _lastOdometer != null) {
        // Convert absolute to relative
        final absolute = double.tryParse(_odometerCtrl.text) ?? 0;
        if (absolute > 0) {
          _odometerCtrl.text = (absolute - _lastOdometer!).toStringAsFixed(1);
        }
      } else if (!_useRelativeMode && _lastOdometer != null) {
        // Convert relative to absolute
        final relative = double.tryParse(_odometerCtrl.text) ?? 0;
        if (relative > 0) {
          _odometerCtrl.text = (_lastOdometer! + relative).toStringAsFixed(1);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fuelTypesAsync = ref.watch(fuelTypesProvider);
    final stationsAsync = ref.watch(stationsProvider);
    final settingsAsync = ref.watch(appSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit fuel' : 'Add fuel'),
        actions: _isEditing
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text('$_date'.substring(0, 10)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          settingsAsync.when(
            loading: () => _buildOdometerField(context, null),
            error: (_, __) => _buildOdometerField(context, null),
            data: (settings) => _buildOdometerField(context, settings),
          ),
          _field(_quantityCtrl, 'Quantity (L)',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _calcTotal('quantity')),
          _field(_priceCtrl, 'Price per unit',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _calcTotal('price')),
          _field(_totalCtrl, 'Total cost',
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => _calcTotal('total')),
          fuelTypesAsync.when(
            loading: () => _field(_fuelTypeCtrl, 'Fuel type'),
            error: (_, __) => _field(_fuelTypeCtrl, 'Fuel type'),
            data: (options) => _autocompleteField(
              _fuelTypeCtrl,
              'Fuel type',
              options: options,
            ),
          ),
          stationsAsync.when(
            loading: () => _field(_stationCtrl, 'Station'),
            error: (_, __) => _field(_stationCtrl, 'Station'),
            data: (options) => _autocompleteField(
              _stationCtrl,
              'Station',
              options: options,
            ),
          ),
          _field(_notesCtrl, 'Notes', maxLines: 2),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_isEditing ? 'Update' : 'Save'),
          ),
        ]),
      ),
    );
  }

  Widget _buildOdometerField(BuildContext context, AppSettings? settings) {
    final mode = settings?.odometerEntryMode ?? OdometerEntryMode.absolute;
    final isRelativeMode = _useRelativeMode || (_lastOdometer == null && mode == OdometerEntryMode.relative);
    
    return Column(
      children: [
        _field(
          _odometerCtrl,
          isRelativeMode ? 'Distance since last fill (km)' : 'Odometer reading (km)',
          keyboardType: TextInputType.numberWithOptions(decimal: true),
        ),
        if (_lastOdometer != null && !_isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 4),
            child: Row(
              children: [
                Text(
                  'Last odometer: ${_lastOdometer!.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _toggleOdometerMode,
                  icon: Icon(_useRelativeMode ? Icons.swap_horiz : Icons.swap_vert),
                  label: Text(_useRelativeMode ? 'Switch to Absolute' : 'Switch to Relative'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _calcTotal(String source) {
    final qty = double.tryParse(_quantityCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final total = double.tryParse(_totalCtrl.text) ?? 0;

    if (source == 'quantity' || source == 'price') {
      if (qty > 0 && price > 0) {
        _totalCtrl.text = (qty * price).toStringAsFixed(2);
      }
    } else if (source == 'total') {
      if (qty > 0 && total > 0) {
        _priceCtrl.text = (total / qty).toStringAsFixed(2);
      } else if (price > 0 && total > 0) {
        _quantityCtrl.text = (total / price).toStringAsFixed(2);
      }
    }
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboardType, int maxLines = 1, void Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _autocompleteField(
    TextEditingController controller,
    String label, {
    required List<String> options,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return options;
          }
          return options.where((option) =>
              option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
        },
        onSelected: (String selection) {
          controller.text = selection;
        },
        fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
          if (fieldController.text != controller.text) {
            fieldController.text = controller.text;
            fieldController.selection = TextSelection.collapsed(offset: controller.text.length);
          }
          return TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            keyboardType: keyboardType,
            decoration: InputDecoration(labelText: label),
            onChanged: (value) {
              controller.text = value;
            },
            onFieldSubmitted: (value) {
              onFieldSubmitted();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200, minWidth: 300),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      title: Text(option),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
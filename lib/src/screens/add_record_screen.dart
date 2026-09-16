import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/providers.dart';

class AddRecordScreen extends ConsumerStatefulWidget {
  const AddRecordScreen({
    super.key,
    required this.vehicleId,
    this.initialRecord,
  });
  final String vehicleId;
  final Record? initialRecord;

  @override
  ConsumerState<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends ConsumerState<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date;
  RecordType _type = RecordType.oilChange;
  final _odometerCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _providerCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  // oil-specific
  final _oilQtyCtrl = TextEditingController();
  final _oilGradeCtrl = TextEditingController();
  final _oilBrandCtrl = TextEditingController();
  final _filterCostCtrl = TextEditingController();
  final _laborCtrl = TextEditingController();
  // repair-specific
  final _partsCtrl = TextEditingController();
  bool _saving = false;
  bool get _isEditing => widget.initialRecord != null;
  bool get _isOil => _type == RecordType.oilChange;
  bool get _isRepair => _type == RecordType.repair;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecord;
    _date = r?.date ?? DateTime.now();
    _type = r?.type ?? RecordType.oilChange;
    if (r != null) {
      _odometerCtrl.text = r.odometer?.toStringAsFixed(1) ?? '';
      _titleCtrl.text = r.title;
      _costCtrl.text = r.cost?.toStringAsFixed(2) ?? '';
      _providerCtrl.text = r.provider;
      _descCtrl.text = r.description;
      _notesCtrl.text = r.notes;
      final d = r.details;
      if (_isOil) {
        _oilQtyCtrl.text = (d['oilQuantity'] as num?)?.toStringAsFixed(2) ?? '';
        _oilGradeCtrl.text = d['oilGrade'] as String? ?? '';
        _oilBrandCtrl.text = d['oilBrand'] as String? ?? '';
        _filterCostCtrl.text = (d['filterCost'] as num?)?.toStringAsFixed(2) ?? '';
        _laborCtrl.text = (d['labor'] as num?)?.toStringAsFixed(2) ?? '';
      }
      if (_isRepair) {
        _partsCtrl.text = (d['partsCost'] as num?)?.toStringAsFixed(2) ?? '';
        _laborCtrl.text = (d['labor'] as num?)?.toStringAsFixed(2) ?? '';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _odometerCtrl, _titleCtrl, _costCtrl, _providerCtrl,
      _descCtrl, _notesCtrl, _oilQtyCtrl, _oilGradeCtrl,
      _oilBrandCtrl, _filterCostCtrl, _laborCtrl, _partsCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final details = <String, dynamic>{};
    if (_isOil) {
      details['oilQuantity'] = double.tryParse(_oilQtyCtrl.text) ?? 0;
      details['oilGrade'] = _oilGradeCtrl.text;
      details['oilBrand'] = _oilBrandCtrl.text;
      details['filterCost'] = double.tryParse(_filterCostCtrl.text) ?? 0;
      details['labor'] = double.tryParse(_laborCtrl.text) ?? 0;
    }
    if (_isRepair) {
      details['partsCost'] = double.tryParse(_partsCtrl.text) ?? 0;
      details['labor'] = double.tryParse(_laborCtrl.text) ?? 0;
    }
    final currency = ref.read(appSettingsNotifierProvider).value?.currency ?? 'NPR';
    final record = Record(
      id: _isEditing ? widget.initialRecord!.id : const Uuid().v4(),
      vehicleId: widget.vehicleId,
      type: _type,
      date: _date,
      odometer: double.tryParse(_odometerCtrl.text),
      cost: double.tryParse(_costCtrl.text),
      currency: currency,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      provider: _providerCtrl.text.trim(),
      details: details,
      createdAt: _isEditing ? widget.initialRecord!.createdAt : now,
      updatedAt: now,
    );
    try {
      if (_isEditing) {
        await ref.read(recordRepositoryProvider).update(record);
      } else {
        await ref.read(recordRepositoryProvider).create(record);
      }
      ref.invalidate(vehicleRecordsProvider(widget.vehicleId));
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
        title: const Text('Delete record?'),
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
      await ref.read(recordRepositoryProvider).delete(widget.initialRecord!.id);
      ref.invalidate(vehicleRecordsProvider(widget.vehicleId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit record' : 'Add record'),
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
          DropdownButtonFormField<RecordType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: RecordType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _type = v);
            },
          ),
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
          _field(_odometerCtrl, 'Odometer',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              required: false),
          _field(_titleCtrl, 'Title', required: true),
          _field(_costCtrl, 'Cost',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              required: false),
          _field(_providerCtrl, 'Provider', required: false),
          _field(_descCtrl, 'Description', maxLines: 2, required: false),
          _field(_notesCtrl, 'Notes', maxLines: 2, required: false),
          if (_isOil) ...[
            const Divider(),
            Text('Oil change specifics',
                style: Theme.of(context).textTheme.titleSmall),
            _field(_oilQtyCtrl, 'Oil quantity (L)',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            _field(_oilGradeCtrl, 'Oil grade / type'),
            _field(_oilBrandCtrl, 'Oil brand'),
            _field(_filterCostCtrl, 'Filter cost',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            _field(_laborCtrl, 'Labor cost',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
          ],
          if (_isRepair) ...[
            const Divider(),
            Text('Repair specifics',
                style: Theme.of(context).textTheme.titleSmall),
            _field(_partsCtrl, 'Parts cost',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            _field(_laborCtrl, 'Labor cost',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
          ],
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
            label: Text(_isEditing ? 'Update' : 'Save'),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboardType,
      int maxLines = 1,
      bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }
}
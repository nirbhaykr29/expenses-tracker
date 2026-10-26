import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';
import '../utils/amount_parser.dart';
import '../utils/formatters.dart';

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({
    super.key,
    required this.repository,
    this.transaction,
  });

  final TransactionRepository repository;
  final TransactionModel? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  static const _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Salary',
    'Freelance',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _type = transaction?.type ?? TransactionType.debit;
    _category = transaction?.category ?? _categories.first;
    _date = transaction == null
        ? DateTime.now()
        : dateFromIso(transaction.date);
    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : '${transaction.amountPaise ~/ 100}.'
                '${(transaction.amountPaise % 100).toString().padLeft(2, '0')}',
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? _parseAmountPaise(String value) => parseAmountPaise(value);

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'SELECT TRANSACTION DATE',
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amountPaise = _parseAmountPaise(_amountController.text);
    if (amountPaise == null) return;
    setState(() => _saving = true);
    final original = widget.transaction;
    final transaction = TransactionModel(
      id: original?.id,
      type: _type,
      amountPaise: amountPaise,
      category: _category,
      date: isoDate(_date),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: original?.createdAt ?? DateTime.now().toIso8601String(),
    );
    try {
      if (original == null) {
        await widget.repository.insert(transaction);
      } else {
        await widget.repository.update(transaction);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save transaction: $error')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'New transaction'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.debit,
                    label: Text('Expense'),
                    icon: Icon(Icons.north_east_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionType.credit,
                    label: Text('Income'),
                    icon: Icon(Icons.south_west_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: 24),
              Text(
                'Amount',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  LengthLimitingTextInputFormatter(15),
                ],
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  prefixText: '₹ ',
                  hintText: '0.00',
                ),
                validator: (value) => _parseAmountPaise(value ?? '') == null
                    ? 'Enter an amount greater than ₹0 (up to 2 decimals).'
                    : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.grid_view_rounded),
                ),
                items:
                    [
                      ..._categories,
                      if (!_categories.contains(_category)) _category,
                    ].map((value) {
                      return DropdownMenuItem(value: value, child: Text(value));
                    }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(14),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(formatDate(isoDate(_date))),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLength: 120,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Save transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

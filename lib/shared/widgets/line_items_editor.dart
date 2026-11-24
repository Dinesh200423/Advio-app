import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';

class _Row {
  _Row(LineItem item)
      : id = item.id,
        description = TextEditingController(text: item.description),
        quantity = TextEditingController(text: _num(item.quantity)),
        price = TextEditingController(text: item.unitPrice == 0 ? '' : _num(item.unitPrice));

  final String id;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController price;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  LineItem toItem() => LineItem(
        id: id,
        description: description.text.trim(),
        quantity: parseAmount(quantity.text),
        unitPrice: parseAmount(price.text),
      );

  void dispose() {
    description.dispose();
    quantity.dispose();
    price.dispose();
  }
}

/// Editable list of quotation / invoice lines. Reports every change through [onChanged].
class LineItemsEditor extends StatefulWidget {
  const LineItemsEditor({super.key, required this.initial, required this.onChanged});
  final List<LineItem> initial;
  final ValueChanged<List<LineItem>> onChanged;

  @override
  State<LineItemsEditor> createState() => _LineItemsEditorState();
}

class _LineItemsEditorState extends State<LineItemsEditor> {
  late final List<_Row> _rows = [
    for (final i in widget.initial) _Row(i),
  ];

  @override
  void initState() {
    super.initState();
    if (_rows.isEmpty) _rows.add(_Row(LineItem(id: newId('li'), description: '')));
    // Make sure the parent knows about the starting rows.
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _notify() => widget.onChanged([for (final r in _rows) r.toItem()]);

  void _add() {
    setState(() => _rows.add(_Row(LineItem(id: newId('li'), description: ''))));
    _notify();
  }

  void _remove(int i) {
    final removed = _rows.removeAt(i);
    setState(() {});
    _notify();
    // Controllers may still be used by the row animating out; dispose a frame later.
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _rows.length; i++)
          Container(
            key: ValueKey(_rows[i].id),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Item ${i + 1}', style: AppText.labelStrong),
                    const Spacer(),
                    if (_rows.length > 1)
                      InkWell(
                        onTap: () => _remove(i),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text('Remove', style: AppText.label.copyWith(color: AppColors.danger)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _rows[i].description,
                  hint: 'Description',
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => _notify(),
                  validator: (v) => Validators.required(v, 'Description'),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppAmountField(
                        controller: _rows[i].quantity,
                        label: 'Qty',
                        onChanged: (_) => _notify(),
                        validator: (v) => Validators.amount(v, label: 'Qty'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: AppAmountField(
                        controller: _rows[i].price,
                        label: 'Unit price',
                        onChanged: (_) => _notify(),
                        validator: (v) => Validators.amount(v, label: 'Price', allowZero: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        AppButton.secondary(label: 'Add item', icon: Icons.add_rounded, onPressed: _add, compact: true),
      ],
    );
  }
}

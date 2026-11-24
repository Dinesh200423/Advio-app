import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';

/// Compact dropdown for list filters. The first entry (null) clears the filter and shows [hint].
class FilterDropdown<T> extends StatelessWidget {
  const FilterDropdown({super.key, required this.hint, required this.value, required this.items, required this.labelOf, required this.onChanged});
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value;
    return PopupMenuButton<T?>(
      initialValue: value,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        PopupMenuItem<T?>(value: null, child: Text(hint)),
        for (final i in items) PopupMenuItem<T?>(value: i, child: Text(labelOf(i))),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected == null ? AppColors.border : AppColors.ink),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected == null ? hint : labelOf(selected),
                overflow: TextOverflow.ellipsis,
                style: AppText.body.copyWith(fontWeight: selected == null ? FontWeight.w400 : FontWeight.w600),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

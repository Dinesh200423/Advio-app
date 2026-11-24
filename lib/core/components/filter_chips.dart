import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';

/// Horizontally scrolling single-select chip row.
///
/// When [allLabel] is given an "All" chip is prepended; selecting it reports
/// `null`. Counts per option can be shown with [countOf].
class FilterChipRow<T> extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.allLabel = 'All',
    this.countOf,
  });

  final List<T> options;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final String Function(T) labelOf;
  final String? allLabel;
  final int Function(T?)? countOf;

  @override
  Widget build(BuildContext context) {
    final entries = <T?>[if (allLabel != null) null, ...options];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = entries[i];
          final isSelected = e == selected;
          final label = e == null ? allLabel! : labelOf(e);
          final count = countOf?.call(e);
          return _Chip(
            label: count == null ? label : '$label  $count',
            selected: isSelected,
            onTap: () => onSelected(e),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? AppColors.primary : AppColors.surface,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primary : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: AppText.labelStrong.copyWith(color: selected ? Colors.white : AppColors.body),
            ),
          ),
        ),
      ),
    );
  }
}

/// Equal-width segmented control for switching between 2-4 views.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE2E2E2), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == index ? AppColors.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: i == index
                          ? const [BoxShadow(color: Color(0x141C1C1C), blurRadius: 6, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.labelStrong.copyWith(
                        color: i == index ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Segmented tabs plus the active tab's content, managing their own state.
class TabbedSection extends StatefulWidget {
  const TabbedSection({super.key, required this.tabs, this.initialIndex = 0});

  /// Tab label â†’ content builder.
  final Map<String, WidgetBuilder> tabs;
  final int initialIndex;

  @override
  State<TabbedSection> createState() => _TabbedSectionState();
}

class _TabbedSectionState extends State<TabbedSection> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final labels = widget.tabs.keys.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(labels: labels, index: _index, onChanged: (i) => setState(() => _index = i)),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_index),
            child: widget.tabs[labels[_index]]!(context),
          ),
        ),
      ],
    );
  }
}

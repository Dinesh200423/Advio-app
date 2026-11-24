import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../utils/formatters.dart';

/// Label rendered above every form control for a consistent look.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required) TextSpan(text: ' *', style: TextStyle(color: AppColors.danger.withValues(alpha: 0.9))),
          ],
        ),
        style: AppText.labelStrong,
      ),
    );
  }
}

/// Standard text input (label above, 52px high, validation aware).
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.obscure = false,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    this.suffix,
    this.prefixText,
    this.textInputAction,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.required = false,
    this.initialValue,
    this.autofocus = false,
    this.onSubmitted,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool obscure;
  final bool readOnly;
  final bool enabled;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;
  final String? prefixText;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool required;
  final String? initialValue;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final multiline = widget.maxLines > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) FieldLabel(widget.label!, required: widget.required),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          initialValue: widget.controller == null ? widget.initialValue : null,
          validator: widget.validator,
          keyboardType: widget.keyboardType ?? (multiline ? TextInputType.multiline : null),
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: multiline ? widget.maxLines : null,
          obscureText: _hidden,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          onTap: widget.onTap,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction ?? (multiline ? TextInputAction.newline : TextInputAction.next),
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          style: AppText.bodyLarge.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixText: widget.prefixText,
            prefixStyle: AppText.bodyLarge.copyWith(fontSize: 15),
            prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 20, color: AppColors.muted),
            suffixIcon: widget.obscure
                ? IconButton(
                    icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    color: AppColors.muted,
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : widget.suffix,
            constraints: multiline ? null : const BoxConstraints(minHeight: AppSpacing.inputHeight),
          ),
        ),
      ],
    );
  }
}

/// Numeric money / quantity input.
class AppAmountField extends StatelessWidget {
  const AppAmountField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '0',
    this.validator,
    this.prefixText,
    this.onChanged,
    this.required = false,
    this.allowDecimal = true,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final String? Function(String?)? validator;
  final String? prefixText;
  final ValueChanged<String>? onChanged;
  final bool required;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      prefixText: prefixText,
      required: required,
      onChanged: onChanged,
      validator: validator,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(allowDecimal ? r'[0-9.,]' : r'[0-9]'))],
    );
  }
}

/// Search field with clear button.
class AppSearchBar extends StatefulWidget {
  const AppSearchBar({super.key, required this.onChanged, this.hint = 'Search', this.controller});
  final ValueChanged<String> onChanged;
  final String hint;
  final TextEditingController? controller;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _c = widget.controller ?? TextEditingController();

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: (v) {
        setState(() {});
        widget.onChanged(v);
      },
      textInputAction: TextInputAction.search,
      style: AppText.bodyLarge.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                color: AppColors.muted,
                tooltip: 'Clear search',
                onPressed: () {
                  _c.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
        constraints: const BoxConstraints(minHeight: 48),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

/// Dropdown bound to a list of values (typically enums).
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.label,
    this.hint,
    this.validator,
    this.icon,
    this.required = false,
    this.leadingOf,
  });

  final List<T> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String Function(T) labelOf;
  final String? label;
  final String? hint;
  final String? Function(T?)? validator;
  final IconData? icon;
  final bool required;
  final Widget? Function(T)? leadingOf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) FieldLabel(label!, required: required),
        DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: items.contains(value) ? value : null,
          isExpanded: true,
          validator: validator,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          dropdownColor: AppColors.surface,
          style: AppText.bodyLarge.copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint ?? 'Select',
            prefixIcon: icon == null ? null : Icon(icon, size: 20, color: AppColors.muted),
            constraints: const BoxConstraints(minHeight: AppSpacing.inputHeight),
          ),
          items: [
            for (final i in items)
              DropdownMenuItem<T>(
                value: i,
                child: Row(
                  children: [
                    if (leadingOf?.call(i) != null) ...[leadingOf!(i)!, const SizedBox(width: 10)],
                    Expanded(child: Text(labelOf(i), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Date (optionally date + time) picker field.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.hint = 'Select date',
    this.firstDate,
    this.lastDate,
    this.withTime = false,
    this.required = false,
    this.validator,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? label;
  final String hint;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool withTime;
  final bool required;
  final String? Function(DateTime?)? validator;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final first = firstDate ?? DateTime(now.year - 3);
    final last = lastDate ?? DateTime(now.year + 5);
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !context.mounted) return;
    var result = DateTime(date.year, date.month, date.day, initial.hour, initial.minute);
    if (withTime) {
      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
      if (t == null || !context.mounted) return;
      result = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    }
    onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: validator ?? (required ? (v) => v == null ? '${label ?? 'Date'} is required' : null : null),
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) FieldLabel(label!, required: required),
            InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              onTap: () => _pick(context),
              child: InputDecorator(
                decoration: InputDecoration(
                  errorText: state.errorText,
                  prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.muted),
                  suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.muted),
                  constraints: const BoxConstraints(minHeight: AppSpacing.inputHeight),
                ),
                child: Text(
                  value == null ? hint : (withTime ? Fmt.dateTime(value!) : Fmt.date(value!)),
                  style: AppText.bodyLarge.copyWith(
                    fontSize: 15,
                    color: value == null ? AppColors.muted.withValues(alpha: 0.8) : AppColors.body,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

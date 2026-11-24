import 'package:flutter/material.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';

/// Receipt attachment control.
///
/// Phase 1 has no file access, so "attach" offers a short list of sample
/// receipts. The real picker will replace [_pick] later.
class ReceiptPicker extends StatelessWidget {
  const ReceiptPicker({super.key, required this.fileName, required this.onChanged});
  final String? fileName;
  final ValueChanged<String?> onChanged;

  static const _samples = ['receipt-photo.jpg', 'invoice-scan.pdf', 'bill-0421.png'];

  Future<void> _pick(BuildContext context) async {
    final choice = await pickOption<String>(context, title: 'Attach a receipt', options: _samples, labelOf: (s) => s);
    if (choice != null) onChanged(choice);
  }

  @override
  Widget build(BuildContext context) {
    if (fileName == null) {
      return InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
            color: AppColors.surface,
          ),
          child: Text('Attach receipt', style: AppText.labelStrong.copyWith(color: AppColors.primary)),
        ),
      );
    }
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(child: Text(fileName!, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500))),
          TextButton(onPressed: () => _pick(context), child: const Text('Change')),
          TextButton(
            onPressed: () => onChanged(null),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

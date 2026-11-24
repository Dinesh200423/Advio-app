import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../../core/constants/app_colors.dart';

/// App mark: an "A" in the wide ADVIO face on an ink tile (lime tile on dark backgrounds).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 72, this.onDark = false});
  final double size;

  /// Lime tile with ink letter, for use on the ink-coloured splash screen.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final bg = onDark ? AppColors.accent : AppColors.ink;
    final fg = onDark ? AppColors.ink : AppColors.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Text('A', style: AppText.wordmark(size * 0.46, color: fg).copyWith(letterSpacing: 0)),
    );
  }
}

/// "ADVIO" in the wordmark style, optionally preceded by the mark.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.size = 20, this.showMark = true, this.color = AppColors.ink});
  final double size;
  final bool showMark;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[AppLogo(size: size * 1.7), SizedBox(width: size * 0.7)],
        Text('ADVIO', style: AppText.wordmark(size, color: color)),
      ],
    );
  }
}

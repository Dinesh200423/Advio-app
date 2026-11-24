import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 8px spacing grid, radii and shared decoration helpers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  /// Horizontal page padding.
  static const double page = 20;

  static const double cardRadius = 20;
  static const double buttonRadius = 14;
  static const double inputHeight = 52;
  static const double touchTarget = 48;
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(color: Color(0x0A1C1C1C), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x051C1C1C), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const raised = [
    BoxShadow(color: Color(0x1A1C1C1C), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class AppDecor {
  static BoxDecoration card({Color? color, bool shadow = true}) => BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: shadow ? AppShadows.card : null,
      );
}

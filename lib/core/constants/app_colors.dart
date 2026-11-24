import 'package:flutter/material.dart';

/// ADVIO palette, taken from the company website: neutral greys, near-black ink
/// and a lime accent. Single source of truth for every colour in the app.
abstract final class AppColors {
  /// Primary actions, active states, links. Same as the website's ink colour.
  static const primary = Color(0xFF1C1C1C);

  /// Headings and strong text.
  static const ink = Color(0xFF1C1C1C);

  /// Brand accent (the website's lime). Used for highlights, never for text on light backgrounds.
  static const accent = Color(0xFFD4F53C);

  /// Darker olive that stays readable on light backgrounds, for secondary highlights and automation.
  static const secondary = Color(0xFF6F8A00);

  static const background = Color(0xFFECECEC);
  static const surface = Color(0xFFFFFFFF);
  static const body = Color(0xFF2B2B2B);
  static const muted = Color(0xFF5E5E5E);
  static const border = Color(0xFFD6D6D6);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  /// Soft tinted background for a semantic colour (badges, status pills).
  static Color tint(Color c, [double opacity = 0.1]) => c.withValues(alpha: opacity);
}

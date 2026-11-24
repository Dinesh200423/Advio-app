import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';

/// Typography: Inter for reading, Krona One (the closest free match to the website's wide display face) for titles and the wordmark.
abstract final class AppText {
  static TextStyle _inter(double size, FontWeight w, Color c, {double? height, double? ls}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: ls);

  /// Page title. Krona is wide, so it runs smaller than a normal 28px heading.
  static TextStyle get pageTitle => GoogleFonts.kronaOne(fontSize: 22, color: AppColors.ink, height: 1.25);

  /// Big figures (totals, percentages) stay in Inter so numbers don't sprawl.
  static TextStyle get display => _inter(32, FontWeight.w700, AppColors.ink, height: 1.15, ls: -0.8);

  /// The ADVIO wordmark: wide letters with generous tracking, as on the website.
  static TextStyle wordmark(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.kronaOne(fontSize: size, color: color, letterSpacing: size * 0.22, height: 1);

  /// Section title: 18-20px semibold.
  static TextStyle get sectionTitle => _inter(18, FontWeight.w600, AppColors.ink, height: 1.3, ls: -0.2);
  static TextStyle get cardTitle => _inter(16, FontWeight.w600, AppColors.ink, height: 1.35);

  /// Body: 14-16px.
  static TextStyle get body => _inter(14, FontWeight.w400, AppColors.body, height: 1.5);
  static TextStyle get bodyLarge => _inter(16, FontWeight.w400, AppColors.body, height: 1.5);
  static TextStyle get bodyStrong => _inter(14, FontWeight.w600, AppColors.ink, height: 1.5);

  /// Labels: 12-13px.
  static TextStyle get label => _inter(13, FontWeight.w500, AppColors.muted, height: 1.4);
  static TextStyle get labelStrong => _inter(13, FontWeight.w600, AppColors.body, height: 1.4);

  /// Captions: 11-12px.
  static TextStyle get caption => _inter(12, FontWeight.w400, AppColors.muted, height: 1.4);

  static TextStyle get metric => _inter(24, FontWeight.w600, AppColors.ink, height: 1.2, ls: -0.5);
  static TextStyle get button => _inter(15, FontWeight.w600, Colors.white, height: 1.2);
}

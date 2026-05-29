import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Named typography scale for the GKK design system.
///
/// All inline `TextStyle(fontSize: ..., fontWeight: ...)` literals should be
/// replaced with references from this class (optionally `.copyWith(color: ...)`).
abstract final class AppTextStyles {
  // ──────────────────────────── Display ────────────────────────────────────

  static final TextStyle display = GoogleFonts.urbanist(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  // ──────────────────────────── Headlines ──────────────────────────────────

  static final TextStyle h1 = GoogleFonts.urbanist(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static final TextStyle h2 = GoogleFonts.urbanist(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static final TextStyle h3 = GoogleFonts.urbanist(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ──────────────────────────── Titles ─────────────────────────────────────

  static final TextStyle title = GoogleFonts.urbanist(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static final TextStyle titleBold = GoogleFonts.urbanist(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ──────────────────────────── Body ───────────────────────────────────────

  static final TextStyle body = GoogleFonts.urbanist(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static final TextStyle bodyBold = GoogleFonts.urbanist(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // ──────────────────────────── Captions ───────────────────────────────────

  static final TextStyle caption = GoogleFonts.urbanist(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static final TextStyle captionBold = GoogleFonts.urbanist(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // ──────────────────────────── Labels / Micro ─────────────────────────────

  /// Navigation labels, micro badges
  static final TextStyle label = GoogleFonts.urbanist(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.textSecondary,
    height: 1.2,
  );

  /// Smallest text — chip labels, section headers
  static final TextStyle micro = GoogleFonts.urbanist(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
    color: AppColors.textTertiary,
    height: 1.2,
  );
}


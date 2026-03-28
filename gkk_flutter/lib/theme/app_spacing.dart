import 'package:flutter/material.dart';

/// Spacing constants based on an 8-point grid.
abstract final class AppSpacing {
  // ──────────────────────────── Base units ─────────────────────────────────

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;

  // ──────────────────────────── Border radii ────────────────────────────────

  static const double radiusXs = 6;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;

  /// Full-pill radius
  static const double radiusFull = 999;

  // ──────────────────────────── Page padding ────────────────────────────────

  static const EdgeInsets pagePadding = EdgeInsets.all(base);

  static const EdgeInsets pagePaddingHoriz = EdgeInsets.symmetric(horizontal: base);

  static const EdgeInsets pagePaddingVert = EdgeInsets.symmetric(vertical: base);

  static const EdgeInsets cardPadding = EdgeInsets.all(md);

  static const EdgeInsets sectionPadding = EdgeInsets.symmetric(vertical: sm);
}

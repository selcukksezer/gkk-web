import 'package:flutter/material.dart';

/// Centralized color palette for the GKK mobile design system.
///
/// All hardcoded `Color(0xFF...)` literals in screens should be replaced with
/// references to constants from this class.
abstract final class AppColors {
  // ──────────────────────────── Backgrounds ───────────────────────────────

  /// Deepest background — page/scaffold background
  static const Color bgDeep = Color(0xFF080B12);

  /// Base background — used for most screens
  static const Color bgBase = Color(0xFF0F1523);

  /// Surface — sits above bgBase (cards, panels)
  static const Color bgSurface = Color(0xFF141B2A);

  /// Card background
  static const Color bgCard = Color(0xFF1A2238);

  /// Elevated card (hover / selected state)
  static const Color bgCardElevated = Color(0xFF1F2B44);

  // ──────────────────────────── Borders ────────────────────────────────────

  static const Color borderFaint = Color(0xFF1A2540);
  static const Color borderDefault = Color(0xFF253154);
  static const Color borderBright = Color(0xFF3B4D70);

  // ──────────────────────────── Text ───────────────────────────────────────

  static const Color textPrimary = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8A9BBE);
  static const Color textTertiary = Color(0xFF4D5F80);
  static const Color textDisabled = Color(0xFF2E3D5C);

  // ──────────────────────────── Gold / Primary ─────────────────────────────

  static const Color gold = Color(0xFFF5C842);
  static const Color goldLight = Color(0xFFFDE68A);
  static const Color goldDim = Color(0xFFB8972F);

  /// 20%-opacity gold for backgrounds / glow
  static const Color goldGlow = Color(0x33F5C842);

  // ──────────────────────────── Blue Accent ────────────────────────────────

  static const Color accentBlue = Color(0xFF5B8FFF);
  static const Color accentBlueDim = Color(0xFF3B5FD0);
  static const Color accentBlueGlow = Color(0x335B8FFF);

  // ──────────────────────────── Purple Accent ──────────────────────────────

  static const Color accentPurple = Color(0xFF9B5CF6);
  static const Color accentPurpleDim = Color(0xFF7A3AE0);
  static const Color accentPurpleGlow = Color(0x339B5CF6);

  // ──────────────────────────── Cyan Accent ────────────────────────────────

  static const Color accentCyan = Color(0xFF06D0D8);
  static const Color accentCyanGlow = Color(0x3306D0D8);

  // ──────────────────────────── Teal Accent ────────────────────────────────

  static const Color accentTeal = Color(0xFF34D399);
  static const Color accentTealGlow = Color(0x3334D399);

  // ──────────────────────────── Status ─────────────────────────────────────

  static const Color success = Color(0xFF22C55E);
  static const Color successGlow = Color(0x3322C55E);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningGlow = Color(0x33F59E0B);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerGlow = Color(0x33EF4444);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoGlow = Color(0x333B82F6);

  // ──────────────────────────── Item Rarity ────────────────────────────────

  static const Color rarityCommon = Color(0xFF9CA3AF);
  static const Color rarityUncommon = Color(0xFF22C55E);
  static const Color rarityRare = Color(0xFF60A5FA);
  static const Color rarityEpic = Color(0xFFA855F7);
  static const Color rarityLegendary = Color(0xFFF59E0B);

  // ──────────────────────────── Overlay / Blur ─────────────────────────────

  /// Dark navy with 85% opacity — used in top/bottom chrome
  static const Color chromeBg = Color(0xDA080B12);

  /// Blue-tinted border for chrome elements
  static const Color chromeBorder = Color(0x4A5B8FFF);

  // ──────────────────────────── Helpers ────────────────────────────────────

  /// Returns the rarity color for an item rarity string.
  static Color forRarity(String rarity) => switch (rarity.toLowerCase()) {
        'uncommon' => rarityUncommon,
        'rare' => rarityRare,
        'epic' => rarityEpic,
        'legendary' => rarityLegendary,
        _ => rarityCommon,
      };
}

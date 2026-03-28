import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'gkk_progress_bar.dart';

/// A compact stat display tile used in stat grids on the home screen and
/// character sheet.
///
/// ```dart
/// GkkStatTile(
///   label: 'GOLD',
///   value: '12.4K',
///   icon: '💰',
///   color: AppColors.gold,
/// )
/// ```
class GkkStatTile extends StatelessWidget {
  const GkkStatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.percent,
    this.subtitle,
    this.onTap,
  });

  /// Short uppercase label shown in the badge (e.g. "GOLD", "XP").
  final String label;

  /// Formatted value string (e.g. "12.4K altin").
  final String value;

  /// Emoji icon displayed in the tile header.
  final String icon;

  /// Accent color for the border, icon badge, and optional progress bar.
  final Color color;

  /// When provided (0.0–1.0), renders a [GkkProgressBar] at the bottom.
  final double? percent;

  /// Optional secondary text beneath [value].
  final String? subtitle;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget inner = Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header row: emoji + label badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 18)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.micro.copyWith(color: color, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Value
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleBold.copyWith(color: AppColors.textPrimary),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.micro.copyWith(color: AppColors.textTertiary),
            ),
          ],
          if (percent != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            GkkProgressBar(value: percent!, color: color, height: 4),
          ],
        ],
      ),
    );

    if (onTap == null) return inner;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        splashColor: color.withValues(alpha: 0.12),
        highlightColor: color.withValues(alpha: 0.07),
        child: inner,
      ),
    );
  }
}

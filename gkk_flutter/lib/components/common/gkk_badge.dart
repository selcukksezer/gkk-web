import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A pill-shaped badge with a colored background.
///
/// ```dart
/// GkkBadge(text: '⚔️ Acemi', color: AppColors.warning)
/// ```
class GkkBadge extends StatelessWidget {
  const GkkBadge({
    super.key,
    required this.text,
    required this.color,
    this.small = false,
  });

  final String text;
  final Color color;

  /// When true, renders a more compact variant.
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? AppSpacing.sm : 10,
        vertical: small ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: (small ? AppTextStyles.micro : AppTextStyles.caption).copyWith(
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

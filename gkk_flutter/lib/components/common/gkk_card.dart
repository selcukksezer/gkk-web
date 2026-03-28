import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// A premium glassmorphism-inspired card component.
///
/// Supports an optional [accentColor] glow border, an optional [onTap] handler
/// (which wraps the card in an InkWell with ripple), and a gradient [gradient]
/// that overrides the default flat background.
class GkkCard extends StatelessWidget {
  const GkkCard({
    super.key,
    required this.child,
    this.padding,
    this.accentColor,
    this.borderGlow = false,
    this.onTap,
    this.gradient,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// When set, the border and optional glow use this color.
  final Color? accentColor;

  /// When true, adds a soft outer glow matching [accentColor].
  final bool borderGlow;

  final VoidCallback? onTap;

  /// Optional gradient — overrides the default solid background color.
  final Gradient? gradient;

  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? AppSpacing.radiusLg;
    final Color borderColor =
        borderGlow && accentColor != null ? accentColor!.withValues(alpha: 0.55) : AppColors.borderDefault;

    final BoxDecoration decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: gradient == null ? AppColors.bgCard : null,
      gradient: gradient,
      border: Border.all(color: borderColor, width: borderGlow ? 1.5 : 1),
      boxShadow: borderGlow && accentColor != null
          ? <BoxShadow>[
              BoxShadow(
                color: accentColor!.withValues(alpha: 0.18),
                blurRadius: 20,
                spreadRadius: -4,
              ),
            ]
          : null,
    );

    final Widget inner = Container(
      padding: padding ?? AppSpacing.cardPadding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return inner;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: (accentColor ?? AppColors.accentBlue).withValues(alpha: 0.1),
        highlightColor: (accentColor ?? AppColors.accentBlue).withValues(alpha: 0.06),
        child: inner,
      ),
    );
  }
}

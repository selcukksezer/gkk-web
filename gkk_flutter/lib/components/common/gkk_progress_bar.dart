import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// Animated progress bar with an optional glow effect.
///
/// ```dart
/// GkkProgressBar(
///   value: 0.62,
///   color: AppColors.accentBlue,
///   label: 'XP',
///   sublabel: '620 / 1000',
/// )
/// ```
class GkkProgressBar extends StatelessWidget {
  const GkkProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
    this.glow = true,
    this.label,
    this.sublabel,
  });

  /// Progress from 0.0 to 1.0.
  final double value;

  /// Bar fill color. Defaults to [AppColors.accentBlue].
  final Color? color;

  /// Height of the progress track.
  final double height;

  /// Whether to render a soft glow beneath the filled portion.
  final bool glow;

  /// Optional left-side label (e.g. "XP", "Energy").
  final String? label;

  /// Optional right-side label (e.g. "620 / 1000").
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final Color barColor = color ?? AppColors.accentBlue;
    final double clamped = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null || sublabel != null) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (label != null)
                Text(label!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: AppTextStyles.captionBold.copyWith(color: barColor),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Stack(
            children: <Widget>[
              // Track
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
              // Fill
              FractionallySizedBox(
                widthFactor: clamped,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        barColor.withValues(alpha: 0.75),
                        barColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    boxShadow: glow
                        ? <BoxShadow>[
                            BoxShadow(
                              color: barColor.withValues(alpha: 0.45),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

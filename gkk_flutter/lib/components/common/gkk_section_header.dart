import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A styled section header with an optional trailing widget.
///
/// ```dart
/// GkkSectionHeader(
///   title: 'Aktif Görevler',
///   trailing: TextButton(onPressed: ..., child: Text('Tümünü Gör')),
/// )
/// ```
class GkkSectionHeader extends StatelessWidget {
  const GkkSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
  });

  final String title;
  final Widget? trailing;

  /// Optional emoji shown before the title text.
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Text(icon!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              title,
              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

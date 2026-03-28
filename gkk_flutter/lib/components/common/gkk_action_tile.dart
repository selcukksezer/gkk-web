import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// A pressable action tile with an emoji icon and label, used in action grids.
///
/// Features a subtle press scale animation and an optional [accentColor] for
/// highlighting high-priority actions.
///
/// ```dart
/// GkkActionTile(
///   emoji: '⚔️',
///   label: 'Zindan',
///   onTap: () => context.push('/dungeon'),
///   accentColor: AppColors.danger,
/// )
/// ```
class GkkActionTile extends StatefulWidget {
  const GkkActionTile({
    super.key,
    required this.emoji,
    required this.label,
    this.onTap,
    this.accentColor,
    this.badge,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;

  /// When provided, tints the border and background with this color.
  final Color? accentColor;

  /// Optional badge text shown in the top-right corner (e.g. "3" for count).
  final String? badge;

  @override
  State<GkkActionTile> createState() => _GkkActionTileState();
}

class _GkkActionTileState extends State<GkkActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final Color accent = widget.accentColor ?? AppColors.borderBright;

    return GestureDetector(
      onTap: enabled ? widget.onTap : null,
      onTapDown: enabled ? _onTapDown : null,
      onTapUp: enabled ? _onTapUp : null,
      onTapCancel: enabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                color: enabled
                    ? accent.withValues(alpha: 0.08)
                    : AppColors.textDisabled.withValues(alpha: 0.06),
                border: Border.all(
                  color: enabled
                      ? accent.withValues(alpha: 0.35)
                      : AppColors.borderFaint,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    widget.emoji,
                    style: TextStyle(
                      fontSize: 26,
                      color: enabled ? null : const Color(0x66FFFFFF),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.label.copyWith(
                      color: enabled ? AppColors.textSecondary : AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bgBase, width: 1.5),
                  ),
                  child: Text(
                    widget.badge!,
                    style: AppTextStyles.micro.copyWith(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

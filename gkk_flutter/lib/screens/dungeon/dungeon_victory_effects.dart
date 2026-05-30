import 'dart:math';
import 'package:flutter/material.dart';

// =============================================================================
// BOYUT SABTLER
// =============================================================================
const double kVictoryBgWidth  = 380.0;
const double kVictoryBgHeight = 380.0;

// =============================================================================
// ROZET SABTLER
// =============================================================================
const double kBadgePositionTop       = 160.0;
const double kBadgeStripeWidth       = 378.0;
const double kBadgeStripeHeight      = 78.0;
const double kBadgeWidth             = 49.0;
const double kBadgeHeight            = 51.0;
const double kBadgeGapBetween        = 12.0;
const double kBadgePaddingVertical   = 3.0;
const double kBadgePaddingHorizontal = 2.0;
const double kBadgeBorderRadius      = 6.0;
const double kBadgeBorderWidth       = 1.0;
const double kBadgeShadowBlur        = 4.0;
const double kBadgeShadowBlur2       = 1.0;
const double kBadgeIconFontSize      = 11.0;
const double kBadgeValueFontSize     = 10.0;
const double kBadgeLabelFontSize     = 6.0;
const double kBadgeSubFontSize       = 6.0;

// =============================================================================
// GLOW / IŞIK HÜZMES SABTLER
// =============================================================================

/// Hüzmelerin görüntü kenarlarından ne kadar dışarı uzandığı (px)
const double kRayOverflow = 80.0;

/// Glow overlay rengi (altın)
const Color kGlowColor = Color(0xFFFFD700);

/// Yumuşak aura blur yarıçapı
const double kAuraBlurRadius = 24.0;

/// Glow min/max opaklığı (pulse sırasında)
const double kGlowOpacityMin = 0.045;
const double kGlowOpacityMax = 0.105;

/// Hüzme sayısı
const int kRayCount = 18;

/// Hüzme min/max opaklığı
const double kRayOpacityMin = 0.04;
const double kRayOpacityMax = 0.22;

/// Hüzme yarı-açısı (rad) — büyütünce hüzmeler kalınlaşır
const double kRayHalfAngle = 0.045;

/// Hüzme başlangıç yarıçapı (ikon merkezinden)
const double kRayInnerRadiusFactor = 0.31;

/// Hüzme bitiş yarıçapı (ikon merkezinden)
const double kRayOuterRadiusFactor = 0.68;

/// Hüzmeler her döngüde ne kadar döner (2π'nin kesri)
const double kRayRotationFraction = 0.06;

/// Glow pulse süresi (ms)
const int kGlowPulseDurationMs = 2400;

/// Görüntü köşe yuvarlaklığı
const double kFrameInnerRadius = 6.0;

// =============================================================================
// VictoryCard
// =============================================================================
class VictoryCard extends StatefulWidget {
  const VictoryCard({
    super.key,
    required this.animation,
    required this.badges,
  });

  final Animation<double> animation;
  final List<Widget> badges;

  @override
  State<VictoryCard> createState() => _VictoryCardState();
}

class _VictoryCardState extends State<VictoryCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: kGlowPulseDurationMs),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.animation,
      child: Center(
        child: SizedBox(
          width: kVictoryBgWidth,
          height: kVictoryBgHeight,
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (context, _) {
              final double glowOpacity = kGlowOpacityMin +
                  _glowAnim.value * (kGlowOpacityMax - kGlowOpacityMin);

              return Stack(
                alignment: Alignment.center,
                children: [
                  // ── 1. Hüzmeler, sabit kart alanının içinde çizilir
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RaysPainter(
                        pulse: _glowAnim.value,
                        rotation: _glowCtrl.value * 2 * pi * kRayRotationFraction,
                        color: kGlowColor,
                      ),
                    ),
                  ),

                  // ── 2. Yumuşak aura, layout boyutunu büyütmez
                  IgnorePointer(
                    child: Container(
                      width: kVictoryBgWidth,
                      height: kVictoryBgHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kFrameInnerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: kGlowColor.withValues(alpha: glowOpacity),
                            blurRadius: kAuraBlurRadius,
                            spreadRadius: -12,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 3. PNG
                  SizedBox(
                    width: kVictoryBgWidth,
                    height: kVictoryBgHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kFrameInnerRadius),
                      child: Image.asset(
                        'assets/dungeon/victory_bg.png',
                        width: kVictoryBgWidth,
                        height: kVictoryBgHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                  // ── 4. Rozetler, eski sabit offset ile
                  Positioned(
                    top: kBadgePositionTop,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      width: kBadgeStripeWidth,
                      height: kBadgeStripeHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: widget.badges,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _RaysPainter — altın ışık hüzmeleri, görüntü merkezinden yayılır
// =============================================================================
class _RaysPainter extends CustomPainter {
  final double pulse;
  final double rotation;
  final Color color;

  const _RaysPainter({
    required this.pulse,
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double diagonal = sqrt(size.width * size.width + size.height * size.height) / 2;
    final double innerRadius = diagonal * kRayInnerRadiusFactor;
    final double outerRadius = diagonal * kRayOuterRadiusFactor;

    for (int i = 0; i < kRayCount; i++) {
      final double baseAngle = (i / kRayCount) * 2 * pi + rotation;
      final double variance = 0.6 + 0.4 * sin(i * 1.7 + pulse * pi);
      final double opacity =
          (kRayOpacityMin + pulse * (kRayOpacityMax - kRayOpacityMin)) *
              variance;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.80),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.00, 0.62, 1.00],
          transform: GradientRotation(baseAngle),
        ).createShader(Rect.fromCircle(center: center, radius: diagonal));

      final Offset p1 = Offset(
        center.dx + cos(baseAngle - kRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle - kRayHalfAngle) * innerRadius,
      );
      final Offset p2 = Offset(
        center.dx + cos(baseAngle + kRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle + kRayHalfAngle) * innerRadius,
      );
      final Offset p3 = Offset(
        center.dx + cos(baseAngle + kRayHalfAngle * 1.9) * outerRadius,
        center.dy + sin(baseAngle + kRayHalfAngle * 1.9) * outerRadius,
      );
      final Offset p4 = Offset(
        center.dx + cos(baseAngle - kRayHalfAngle * 1.9) * outerRadius,
        center.dy + sin(baseAngle - kRayHalfAngle * 1.9) * outerRadius,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) =>
      old.pulse != pulse || old.rotation != rotation;
}

// =============================================================================
// VictoryBadge
// =============================================================================
class VictoryBadge extends StatelessWidget {
  const VictoryBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kBadgeWidth,
      height: kBadgeHeight,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: kBadgePaddingVertical,
          horizontal: kBadgePaddingHorizontal,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(kBadgeBorderRadius),
          border: Border.all(
              color: color.withValues(alpha: 0.55), width: kBadgeBorderWidth),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: kBadgeShadowBlur,
              spreadRadius: 0,
            ),
            BoxShadow(
              color: color.withValues(alpha: 0.20),
              blurRadius: kBadgeShadowBlur2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: TextStyle(fontSize: kBadgeIconFontSize)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: kBadgeValueFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: kBadgeLabelFontSize,
                letterSpacing: 0.5,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 1),
              Text(
                sub!,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: kBadgeSubFontSize,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Defeat Effect Constants
// =============================================================================
const Color kDefeatGlowColor = Color(0xFFB91C1C);
const Color kDefeatRayColor = Color(0xFF7F1D1D);
const double kDefeatGlowOpacityMin = 0.03;
const double kDefeatGlowOpacityMax = 0.10;
const double kDefeatAuraBlurRadius = 20.0;
const int kDefeatRayCount = 14;
const double kDefeatRayOpacityMin = 0.015;
const double kDefeatRayOpacityMax = 0.08;
const double kDefeatRayHalfAngle = 0.035;
const double kDefeatRayInnerRadiusFactor = 0.34;
const double kDefeatRayOuterRadiusFactor = 0.74;
const double kDefeatRayRotationFraction = 0.04;
const double kDefeatStripeTop = 190.0;
const double kDefeatStripeHeight = 82.0;

// =============================================================================
// DefeatCard
// =============================================================================
class DefeatCard extends StatefulWidget {
  const DefeatCard({
    super.key,
    required this.animation,
    required this.notices,
  });

  final Animation<double> animation;
  final List<String> notices;

  @override
  State<DefeatCard> createState() => _DefeatCardState();
}

class _DefeatCardState extends State<DefeatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fxCtrl;
  late final Animation<double> _fxAnim;

  @override
  void initState() {
    super.initState();
    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _fxAnim = CurvedAnimation(parent: _fxCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: widget.animation,
      child: Center(
        child: SizedBox(
          width: kVictoryBgWidth,
          height: kVictoryBgHeight,
          child: AnimatedBuilder(
            animation: _fxAnim,
            builder: (context, _) {
              final glowOpacity = kDefeatGlowOpacityMin +
                  _fxAnim.value *
                      (kDefeatGlowOpacityMax - kDefeatGlowOpacityMin);

              return Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DefeatRaysPainter(
                        pulse: _fxAnim.value,
                        rotation:
                            _fxCtrl.value * 2 * pi * kDefeatRayRotationFraction,
                        color: kDefeatRayColor,
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Container(
                      width: kVictoryBgWidth,
                      height: kVictoryBgHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kFrameInnerRadius),
                        boxShadow: [
                          BoxShadow(
                            color: kDefeatGlowColor.withValues(alpha: glowOpacity),
                            blurRadius: kDefeatAuraBlurRadius,
                            spreadRadius: -12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: kVictoryBgWidth,
                    height: kVictoryBgHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(kFrameInnerRadius),
                      child: Image.asset(
                        'assets/dungeon/defeatdungeon_bg.png',
                        width: kVictoryBgWidth,
                        height: kVictoryBgHeight,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  Positioned(
                    top: kDefeatStripeTop,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                      height: kDefeatStripeHeight,
                      child: Center(
                        child: Container(
                          width: kBadgeStripeWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          color: const Color(0xCC06080C),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: widget.notices
                                .map(
                                  (line) => Text(
                                    line,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DefeatRaysPainter extends CustomPainter {
  const _DefeatRaysPainter({
    required this.pulse,
    required this.rotation,
    required this.color,
  });

  final double pulse;
  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final diagonal = sqrt(size.width * size.width + size.height * size.height) / 2;
    final innerRadius = diagonal * kDefeatRayInnerRadiusFactor;
    final outerRadius = diagonal * kDefeatRayOuterRadiusFactor;

    for (int i = 0; i < kDefeatRayCount; i++) {
      final baseAngle = (i / kDefeatRayCount) * 2 * pi + rotation;
      final variance = 0.7 + 0.3 * sin(i * 1.4 + pulse * pi);
      final opacity =
          (kDefeatRayOpacityMin +
                  pulse * (kDefeatRayOpacityMax - kDefeatRayOpacityMin)) *
              variance;

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: opacity * 0.75),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.72, 1.0],
          transform: GradientRotation(baseAngle),
        ).createShader(Rect.fromCircle(center: center, radius: diagonal));

      final p1 = Offset(
        center.dx + cos(baseAngle - kDefeatRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle - kDefeatRayHalfAngle) * innerRadius,
      );
      final p2 = Offset(
        center.dx + cos(baseAngle + kDefeatRayHalfAngle) * innerRadius,
        center.dy + sin(baseAngle + kDefeatRayHalfAngle) * innerRadius,
      );
      final p3 = Offset(
        center.dx + cos(baseAngle + kDefeatRayHalfAngle * 2.1) * outerRadius,
        center.dy + sin(baseAngle + kDefeatRayHalfAngle * 2.1) * outerRadius,
      );
      final p4 = Offset(
        center.dx + cos(baseAngle - kDefeatRayHalfAngle * 2.1) * outerRadius,
        center.dy + sin(baseAngle - kDefeatRayHalfAngle * 2.1) * outerRadius,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DefeatRaysPainter old) =>
      old.pulse != pulse || old.rotation != rotation;
}

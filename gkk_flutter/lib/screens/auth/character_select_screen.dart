import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _CharacterClassOption {
  const _CharacterClassOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.titleLine,
    required this.traitSummary,
    required this.accentColor,
    required this.imageAsset,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String titleLine;
  final String traitSummary;
  final Color accentColor;
  final String imageAsset;
}

class CharacterSelectScreen extends ConsumerStatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  ConsumerState<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends ConsumerState<CharacterSelectScreen>
    with SingleTickerProviderStateMixin {
  bool _loadingClasses = true;
  bool _submitting = false;
  String? _selectedClassId;
  String? _error;

  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  List<_CharacterClassOption> _classes = const <_CharacterClassOption>[
    _CharacterClassOption(
      id: 'warrior',
      name: 'Savaşçı',
      description: 'Yüksek savunma ve güç.',
      icon: Icons.shield_outlined,
      titleLine: 'Frontline Dominator',
      traitSummary: 'STR / DEF / AGG',
      accentColor: Color(0xFFD8A63C),
      imageAsset: 'assets/characters/savasci.jpg',
    ),
    _CharacterClassOption(
      id: 'alchemist',
      name: 'Simyacı',
      description: 'İksir ve destek odaklı denge.',
      icon: Icons.auto_fix_high_outlined,
      titleLine: 'Arcane Field Engineer',
      traitSummary: 'INT / CTRL / SUP',
      accentColor: Color(0xFF63D1C5),
      imageAsset: 'assets/characters/simyaci.jpg',
    ),
    _CharacterClassOption(
      id: 'shadow',
      name: 'Gölge',
      description: 'Yüksek hasar ve çeviklik.',
      icon: Icons.gps_fixed_outlined,
      titleLine: 'Precision Elimination',
      traitSummary: 'DEX / SPD / BURST',
      accentColor: Color(0xFF8E93FF),
      imageAsset: 'assets/characters/golge.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });

    try {
      final dynamic response = await SupabaseService.client.rpc('get_character_classes');
      if (response is! Map<String, dynamic>) {
        return;
      }

      final bool success = response['success'] == true;
      final List<dynamic>? classes = response['classes'] as List<dynamic>?;
      if (!success || classes == null || classes.isEmpty) {
        return;
      }

      final Map<String, IconData> iconMap = <String, IconData>{
        'warrior': Icons.shield_outlined,
        'alchemist': Icons.auto_fix_high_outlined,
        'shadow': Icons.gps_fixed_outlined,
      };

      final Map<String, ({String titleLine, String traitSummary, Color accentColor, String imageAsset})> presentationMap =
          <String, ({String titleLine, String traitSummary, Color accentColor, String imageAsset})>{
        'warrior': (
          titleLine: 'Frontline Dominator',
          traitSummary: 'STR / DEF / AGG',
          accentColor: const Color(0xFFD8A63C),
          imageAsset: 'assets/characters/savasci.jpg',
        ),
        'alchemist': (
          titleLine: 'Arcane Field Engineer',
          traitSummary: 'INT / CTRL / SUP',
          accentColor: const Color(0xFF63D1C5),
          imageAsset: 'assets/characters/simyaci.jpg',
        ),
        'shadow': (
          titleLine: 'Precision Elimination',
          traitSummary: 'DEX / SPD / BURST',
          accentColor: const Color(0xFF8E93FF),
          imageAsset: 'assets/characters/golge.jpg',
        ),
      };

      final List<_CharacterClassOption> parsed = classes
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> cls) {
        final String id = (cls['id'] as String?) ?? '';
        final presentation = presentationMap[id] ??
            (
              titleLine: 'Adaptive Specialist',
              traitSummary: 'BAL / FLEX / CORE',
              accentColor: const Color(0xFFD8A63C),
              imageAsset: 'assets/characters/savasci.jpg',
            );
        return _CharacterClassOption(
          id: id,
          name: (cls['name_tr'] as String?) ?? id,
          description: (cls['description_tr'] as String?) ?? '',
          icon: iconMap[id] ?? Icons.person_outline,
          titleLine: presentation.titleLine,
          traitSummary: presentation.traitSummary,
          accentColor: presentation.accentColor,
          imageAsset: presentation.imageAsset,
        );
      }).where((cls) => cls.id.isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        _classes = parsed;
        _selectedClassId ??= parsed.first.id;
      }
    } catch (_) {
      _error = 'Sınıf listesi yüklenemedi.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingClasses = false;
        });
      }
    }
  }

  Future<void> _selectClass() async {
    if (_selectedClassId == null || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final String selectedClass = _selectedClassId!;
      bool persisted = false;

      try {
        final dynamic response = await SupabaseService.client.rpc(
          'select_character_class',
          params: <String, dynamic>{'p_class_id': selectedClass},
        );
        if (response is! Map<String, dynamic> || response['success'] != false) {
          persisted = true;
        }
      } catch (_) {
        persisted = false;
      }

      if (!persisted) {
        final currentUser = SupabaseService.client.auth.currentUser;
        if (currentUser == null) {
          throw Exception('Kullanıcı oturumu bulunamadı.');
        }

        await SupabaseService.client
            .from('users')
            .update(<String, dynamic>{'character_class': selectedClass}).eq('auth_id', currentUser.id);
      }

      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sınıf seçimi başarısız oldu. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  _CharacterClassOption get _activeClass {
    return _classes.firstWhere(
      (cls) => cls.id == _selectedClassId,
      orElse: () => _classes.first,
    );
  }

  void _handleClassChanged(String classId) {
    if (_submitting) {
      return;
    }

    setState(() {
      _selectedClassId = classId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final _CharacterClassOption activeClass = _activeClass;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const Positioned.fill(
            child: ColoredBox(color: Color(0xFF08090C)),
          ),
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: <Color>[
                    activeClass.accentColor.withValues(alpha: 0.12),
                    const Color(0xFF08090C),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.42),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.68),
                  ],
                  stops: const <double>[0, 0.45, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 430;
                final bool disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                return Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 16 : 22, 18, compact ? 16 : 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildHeader(activeClass),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _buildCharacterStage(activeClass, compact, disableAnimations),
                      ),
                      const SizedBox(height: 18),
                      _buildBottomSheet(activeClass, compact),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(_CharacterClassOption activeClass) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'GKK // CHARACTER SELECT',
          style: TextStyle(
            color: Color(0xFFD9AE57),
            fontSize: 12,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            activeClass.name.toUpperCase(),
            key: ValueKey<String>(activeClass.id),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            activeClass.titleLine,
            key: ValueKey<String>('title_${activeClass.id}'),
            style: TextStyle(
              color: activeClass.accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildCharacterStage(_CharacterClassOption activeClass, bool compact, bool disableAnimations) {
    final Duration duration = disableAnimations ? Duration.zero : const Duration(milliseconds: 420);

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final Animation<Offset> slideAnimation = Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: AnimatedBuilder(
        key: ValueKey<String>(activeClass.id),
        animation: disableAnimations ? kAlwaysCompleteAnimation : _glowAnimation,
        builder: (BuildContext context, Widget? child) {
          final double t = disableAnimations ? 0.5 : _glowAnimation.value;
          // Breathing pulse: blur 28→60, border alpha 0.28→0.72, outer spread 0→8
          final double blurRadius = 28 + 32 * t;
          final double borderAlpha = 0.28 + 0.44 * t;
          final double spreadRadius = 8 * t;
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 28 : 34),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  activeClass.accentColor.withValues(alpha: 0.22),
                  const Color(0xFF15171B),
                  const Color(0xFF0E1014),
                ],
                stops: const <double>[0, 0.42, 1],
              ),
              border: Border.all(
                color: activeClass.accentColor.withValues(alpha: borderAlpha),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                // inner warm core glow
                BoxShadow(
                  color: activeClass.accentColor.withValues(alpha: 0.12 + 0.18 * t),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
                // outer breathing halo
                BoxShadow(
                  color: activeClass.accentColor.withValues(alpha: 0.10 + 0.22 * t),
                  blurRadius: blurRadius,
                  spreadRadius: spreadRadius,
                  offset: const Offset(0, 4),
                ),
                // deep bottom shadow
                BoxShadow(
                  color: activeClass.accentColor.withValues(alpha: 0.16),
                  blurRadius: 36,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: child,
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 28 : 34),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // ── Dark card base ───────────────────────────────────────────
              const ColoredBox(color: Color(0xFF0E1014)),
              // ── Character artwork ──────────────────────────────────────
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<String>('image_${activeClass.id}'),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: disableAnimations ? 1 : 0.96, end: 1),
                  builder: (BuildContext context, double value, Widget? child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Hero(
                    tag: 'character-card-${activeClass.id}',
                    // ShaderMask: fade out bottom (into dark) + side edges
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: <double>[0.0, 0.52, 0.78, 1.0],
                          colors: <Color>[
                            Colors.white,
                            Colors.white,
                            Color(0xAAFFFFFF),
                            Color(0x00FFFFFF),
                          ],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        activeClass.imageAsset,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                          return Center(
                            child: Icon(
                              activeClass.icon,
                              size: compact ? 84 : 110,
                              color: activeClass.accentColor.withValues(alpha: 0.85),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // ── Accent color tint overlay (soft-light blend) ────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        activeClass.accentColor.withValues(alpha: 0.10),
                        const Color(0x00000000),
                        activeClass.accentColor.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Corner vignette (dark edges bleed into card bg) ─────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: <Color>[
                        const Color(0x00000000),
                        const Color(0x00000000),
                        const Color(0xCC080A0D),
                      ],
                      stops: const <double>[0.0, 0.60, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xB8121418),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: activeClass.accentColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                activeClass.traitSummary,
                                style: TextStyle(
                                  color: activeClass.accentColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Icon(activeClass.icon, color: activeClass.accentColor),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeClass.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeClass.description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSheet(_CharacterClassOption activeClass, bool compact) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 22, 18, compact ? 16 : 22, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xE6111218),
            const Color(0xE01A1C22),
            activeClass.accentColor.withValues(alpha: 0.12),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x66000000), blurRadius: 32, offset: Offset(0, 18)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Sınıfını seç ve maceraya atıl.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.35),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: activeClass.accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: activeClass.accentColor.withValues(alpha: 0.45)),
                ),
                child: Text(
                  activeClass.traitSummary,
                  style: TextStyle(
                    color: activeClass.accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _classes.length,
              separatorBuilder: (BuildContext context, int index) => const SizedBox(width: 12),
              itemBuilder: (BuildContext context, int index) {
                final _CharacterClassOption cls = _classes[index];
                final bool selected = cls.id == _selectedClassId;
                return GestureDetector(
                  onTap: _loadingClasses ? null : () => _handleClassChanged(cls.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 188,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected ? cls.accentColor : Colors.white.withValues(alpha: 0.12),
                        width: selected ? 1.5 : 1,
                      ),
                      color: selected
                          ? cls.accentColor.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned.fill(
                          child: Image.asset(
                            cls.imageAsset,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: <Color>[
                                      cls.accentColor.withValues(alpha: 0.28),
                                      const Color(0xFF131519),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Icon(cls.icon, color: cls.accentColor, size: 42),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black.withValues(alpha: 0.02),
                                  Colors.black.withValues(alpha: 0.3),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                                stops: const <double>[0, 0.45, 1],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(cls.icon, color: selected ? cls.accentColor : Colors.white70, size: 22),
                              const SizedBox(height: 8),
                              Text(
                                cls.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                cls.titleLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: cls.accentColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: activeClass.accentColor.withValues(alpha: 0.08),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Operasyon Özeti',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeClass.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.72), height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 150,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: activeClass.accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _loadingClasses || _selectedClassId == null || _submitting ? null : _selectClass,
                    child: _submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text(
                            'Maceraya Başla',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_loadingClasses) ...<Widget>[
            const SizedBox(height: 14),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }
}

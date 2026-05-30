import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/gkk_action_tile.dart';
import '../../components/common/gkk_card.dart';
import '../../components/common/gkk_progress_bar.dart';
import '../../components/common/gkk_stat_tile.dart';
import '../../components/layout/game_chrome.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

import 'widgets/pantheon_board.dart';
import 'widgets/hero_showcase.dart';
import 'widgets/sticky_action_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHomeData();
    });
  }

  Future<void> _loadHomeData() async {
    await Future.wait<void>(<Future<void>>[
      ref.read(playerProvider.notifier).loadProfile(),
      ref.read(inventoryProvider.notifier).loadInventory(silent: true),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: 'Home',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
          ref.read(inventoryProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.home),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        PlayerStatus.error => _HomeErrorView(
          message: playerState.errorMessage ?? 'Profil yüklenemedi.',
          onRetry: _loadHomeData,
        ),
        PlayerStatus.ready => RefreshIndicator(
          onRefresh: _loadHomeData,
          child: _HomeDashboard(
            profile: playerState.profile!,
            inventoryState: inventoryState,
            onRefresh: _loadHomeData,
          ),
        ),
      },
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDashboard extends ConsumerStatefulWidget {
  const _HomeDashboard({
    required this.profile,
    required this.inventoryState,
    required this.onRefresh,
  });

  final PlayerProfile profile;
  final InventoryState inventoryState;
  final Future<void> Function() onRefresh;

  @override
  ConsumerState<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<_HomeDashboard> {
  final bool _showAllActions = false;

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = widget.profile;
    
    bool isFuture(String? dateStr) {
      if (dateStr == null) return false;
      final d = DateTime.tryParse(dateStr);
      if (d == null) return false;
      return d.isAfter(DateTime.now());
    }

    final bool inHospital = isFuture(profile.hospitalUntil);
    final bool inPrison = isFuture(profile.prisonUntil);

    final int energy = profile.energy;
    final int maxEnergy = profile.maxEnergy;
    final int tolerance = profile.addictionLevel;
    final int reputation = (profile.reputation ?? 0).clamp(0, 999999999);

    final double energyPercent = _percent(energy, maxEnergy);
    final double tolerancePercent = tolerance.clamp(0, 100) / 100;

    final _EquipmentStats eqStats = _calculateEquipmentStats(
      widget.inventoryState.equippedItems,
    );
    final int totalPower = _calculateTotalPower(
      eqStats: eqStats,
      level: profile.level,
      reputation: reputation,
    );
    final _ReputationTier tier = _getReputationTier(reputation);

    final List<InventoryItem> potionItems = widget.inventoryState.items
        .where((item) => item.itemType == ItemType.potion && item.quantity > 0)
        .toList();

    return Stack(
      children: <Widget>[
              // ── Deep background gradient ────────────────────────────────────
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Color(0xFF070B14), Color(0xFF030509)],
                    ),
                  ),
                ),
              ),
              // ── Ambient glow orbs ───────────────────────────────────────────
              Positioned(
                top: -180,
                left: -140,
                child: IgnorePointer(
                  child: Container(
                    width: 480,
                    height: 480,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[Color(0x2A5B8FFF), Color(0x005B8FFF)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -220,
                right: -160,
                child: IgnorePointer(
                  child: Container(
                    width: 520,
                    height: 520,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[Color(0x2234D399), Color(0x0034D399)],
                      ),
                    ),
                  ),
                ),
              ),
              // ── Scrollable content ──────────────────────────────────────────
              Positioned.fill(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.md,
                    AppSpacing.base,
                    100, // Extra padding for sticky action bar
                  ),
                  children: <Widget>[
                    // Promo Banner
                    const _CratePromoBanner(),
                    const SizedBox(height: AppSpacing.md),

                    // Hero Showcase (Character & Equip)
                    HeroShowcase(
                      profile: profile,
                      inventoryState: widget.inventoryState,
                      totalPower: totalPower,
                      reputation: reputation,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // Pantheon Leaderboard
                    const PantheonBoard(),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),

              // ── Sticky Action Bar (Float) ───────────────────────────────────
              const Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: StickyActionBar(),
              ),
              // Floating warning stack at top-right
              if (inHospital || inPrison || energy < 20 || tolerance > 60)
                Positioned(
                  top: 0,
                  right: 16,
                  child: SafeArea(
                    child: _WarningStack(
                      hospitalUntil: profile.hospitalUntil,
                      prisonUntil: profile.prisonUntil,
                      energy: energy,
                      maxEnergy: maxEnergy,
                      tolerance: tolerance,
                    ),
                  ),
                ),
            ],
    );
  }

  Future<void> _showPotionModal(
    BuildContext context,
    List<InventoryItem> potionItems,
    PlayerProfile profile,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '🧪 İksir Kullan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Tolerans: %${profile.addictionLevel} • Enerji: ${profile.energy}/${profile.maxEnergy}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (potionItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Envanterde iksir bulunamadı'),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: potionItems.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = potionItems[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          title: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '+${item.energyRestore} enerji • +${item.toleranceIncrease} tolerans • x${item.quantity}',
                          ),
                          trailing: FilledButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              final bool ok = await ref
                                  .read(inventoryProvider.notifier)
                                  .useItem(item: item);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? '${item.name} kullanıldı!'
                                          : '${item.name} kullanılamadı.',
                                    ),
                                  ),
                                );
                                if (ok) widget.onRefresh();
                              }
                            },
                            child: const Text('Kullan'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _WarningStack extends StatelessWidget {
  const _WarningStack({
    required this.hospitalUntil,
    required this.prisonUntil,
    required this.energy,
    required this.maxEnergy,
    required this.tolerance,
  });

  final String? hospitalUntil;
  final String? prisonUntil;
  final int energy;
  final int maxEnergy;
  final int tolerance;

  bool _isFuture(String? dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    return date.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> banners = <Widget>[];
    
    final bool inHospital = _isFuture(hospitalUntil);
    final bool inPrison = _isFuture(prisonUntil);

    if (inHospital || inPrison) {
      banners.add(
        _ActiveStatusPill(
          icon: inHospital ? '🏥' : '👮',
          title: inHospital ? 'Hastanede' : 'Hapiste',
          until: inHospital 
              ? DateTime.parse(hospitalUntil!).toLocal() 
              : DateTime.parse(prisonUntil!).toLocal(),
          color: inHospital ? AppColors.danger : Colors.orangeAccent,
        ),
      );
    }

    if (energy < 20) {
      banners.add(
        _StaticStatusPill(
          icon: '⚡',
          text: 'Kritik Enerji',
          color: AppColors.warning,
        ),
      );
    }

    if (tolerance > 60) {
      banners.add(
        _StaticStatusPill(
          icon: '⚠️',
          text: 'Yüksek Tolerans',
          color: tolerance >= 80 ? AppColors.danger : AppColors.warning,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: banners
          .map(
            (banner) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: banner,
            ),
          )
          .toList(),
    );
  }
}

class _StaticStatusPill extends StatelessWidget {
  const _StaticStatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveStatusPill extends StatefulWidget {
  const _ActiveStatusPill({
    required this.icon,
    required this.title,
    required this.until,
    required this.color,
  });

  final String icon;
  final String title;
  final DateTime until;
  final Color color;

  @override
  State<_ActiveStatusPill> createState() => _ActiveStatusPillState();
}

class _ActiveStatusPillState extends State<_ActiveStatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00';
    final int minutes = d.inMinutes;
    final int seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final diff = widget.until.difference(now);
        final isFinished = diff.isNegative;

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: widget.color.withValues(alpha: _pulseAnimation.value),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: _pulseAnimation.value * 0.5),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(widget.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isFinished ? 'BİTTİ' : _formatDuration(diff),
                            style: AppTextStyles.caption.copyWith(
                              color: isFinished ? AppColors.success : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [ui.FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    final cell = 20.0;
    for (var x = 0.0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CratePromoBanner extends StatelessWidget {
  const _CratePromoBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.loot),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 200,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const RadialGradient(
                  center: Alignment(0.6, 0.0),
                  radius: 1.5,
                  colors: [Color(0xFF8B0000), Color(0xFF1A0000)],
                ),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
          ),
          // Image escaping bounds
          Positioned(
            right: -50,
            top: -50,
            bottom: -50,
            width: 280,
            child: Image.asset(
              'assets/elements/redcase512px.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
          // Left Content
          Positioned(
            left: 20,
            top: 24,
            bottom: 24,
            right: 180,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'KASA AÇ',
                  style: GoogleFonts.urbanist(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sınırlı bir süre için.\nEfsanevi hediyeler seni bekliyor.',
                  style: GoogleFonts.urbanist(
                    textStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50000), Color(0xFF990000)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 4),
                        blurRadius: 8,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.3),
                        offset: const Offset(0, 1),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFFF3333).withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '500 ile Aç',
                        style: GoogleFonts.urbanist(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.diamond,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Timer Top Center of Crate
          Positioned(
            right: 45,
            top: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeBlock('06', 'Sa'),
                  _buildTimeDivider(),
                  _buildTimeBlock('32', 'Dk'),
                  _buildTimeDivider(),
                  _buildTimeBlock('12', 'Sn'),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBlock(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.urbanist(
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.urbanist(
            textStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: GoogleFonts.urbanist(
          textStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.gold,
    required this.gems,
    required this.energy,
    required this.maxEnergy,
    required this.energyPercent,
    required this.tolerance,
    required this.tolerancePercent,
    required this.reputation,
    required this.tier,
    required this.totalPower,
  });

  final int gold;
  final int gems;
  final int energy;
  final int maxEnergy;
  final double energyPercent;
  final int tolerance;
  final double tolerancePercent;
  final int reputation;
  final _ReputationTier tier;
  final int totalPower;

  @override
  Widget build(BuildContext context) {
    final List<_StatItem> stats = <_StatItem>[
      _StatItem(
        label: 'GOLD',
        emoji: '💰',
        value: _gold(gold),
        color: AppColors.gold,
      ),
      _StatItem(
        label: 'GEM',
        emoji: '💎',
        value: _compact(gems),
        color: AppColors.accentPurple,
      ),
      _StatItem(
        label: 'ENERJİ',
        emoji: '⚡',
        value: '$energy/$maxEnergy',
        color: AppColors.accentCyan,
        percent: energyPercent,
      ),
      _StatItem(
        label: 'TOLERANS',
        emoji: '🧪',
        value: '$tolerance%',
        color: AppColors.danger,
        percent: tolerancePercent,
      ),
      _StatItem(
        label: 'İTİBAR',
        emoji: '⭐',
        value: '${_compact(reputation)} (${tier.title})',
        color: tier.color,
      ),
      _StatItem(
        label: 'GÜÇ',
        emoji: '🔥',
        value: _compact(totalPower),
        color: AppColors.accentBlue,
      ),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final _StatItem s = stats[index];
        return GkkStatTile(
          label: s.label,
          value: s.value,
          icon: s.emoji,
          color: s.color,
          percent: s.percent,
        );
      },
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.inHospital,
    required this.inPrison,
    required this.onNavigateInventory,
    required this.onNavigateMarket,
    required this.onNavigateQuests,
    required this.onComingSoon,
  });

  final bool inHospital;
  final bool inPrison;
  final VoidCallback onNavigateInventory;
  final VoidCallback onNavigateMarket;
  final VoidCallback onNavigateQuests;
  final void Function(String message) onComingSoon;

  @override
  Widget build(BuildContext context) {
    final bool restricted = inHospital || inPrison;
    final List<_ActionItem> actions = <_ActionItem>[
      _ActionItem(
        emoji: '⚔️',
        label: 'Koparma',
        onTap: restricted
            ? null
            : () => onComingSoon('Koparma ekrani siradaki adimda acilacak.'),
        color: AppColors.danger,
      ),
      _ActionItem(
        emoji: '📜',
        label: 'Görevler',
        onTap: onNavigateQuests,
        color: AppColors.accentBlue,
      ),
      _ActionItem(
        emoji: '💰',
        label: 'Market',
        onTap: onNavigateMarket,
        color: AppColors.gold,
      ),
      _ActionItem(
        emoji: '🔥',
        label: 'Geliştirme',
        onTap: onNavigateInventory,
        color: AppColors.accentCyan,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final _ActionItem item = actions[index];
        return GkkActionTile(
          emoji: item.emoji,
          label: item.label,
          onTap: item.onTap,
          accentColor: item.color,
        );
      },
    );
  }
}

class _QuestSection extends StatelessWidget {
  const _QuestSection();

  final List<_QuestItem> _quests = const <_QuestItem>[
    _QuestItem(
      id: 'q1',
      title: 'Demir Madeni',
      progress: 3,
      goal: 10,
      icon: '⛏️',
    ),
    _QuestItem(
      id: 'q2',
      title: 'Karanlık Orman\'ı Temizle',
      progress: 1,
      goal: 3,
      icon: '🏰',
    ),
    _QuestItem(
      id: 'q3',
      title: '5 İksir Kullan',
      progress: 2,
      goal: 5,
      icon: '🧪',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _quests.map((quest) {
        final double pct = quest.goal <= 0
            ? 0
            : (quest.progress / quest.goal).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GkkCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            accentColor: AppColors.accentBlue,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(quest.icon, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        quest.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(pct * 100).round()}%',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                GkkProgressBar(
                  value: pct,
                  color: AppColors.accentBlue,
                  height: 5,
                ),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${quest.progress}/${quest.goal} tamamlandı',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PotionAction extends StatelessWidget {
  const _PotionAction({required this.potionCount, required this.onTap});

  final int potionCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GkkCard(
      accentColor: AppColors.success,
      borderGlow: potionCount > 0,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Text('🧪', style: TextStyle(fontSize: 28)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('İksir Kullan', style: AppTextStyles.bodyBold),
                Text(
                  '$potionCount mevcut • Enerji yenile',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.expanded,
    required this.onToggle,
    required this.onNavigateCrafting,
    required this.onNavigateEquipment,
    required this.onNavigateShop,
    required this.onNavigateBank,
    required this.onNavigateLeaderboard,
    required this.onNavigatePvp,
    required this.onNavigateFacilities,
    required this.onNavigateSeason,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onNavigateCrafting;
  final VoidCallback onNavigateEquipment;
  final VoidCallback onNavigateShop;
  final VoidCallback onNavigateBank;
  final VoidCallback onNavigateLeaderboard;
  final VoidCallback onNavigatePvp;
  final VoidCallback onNavigateFacilities;
  final VoidCallback onNavigateSeason;

  @override
  Widget build(BuildContext context) {
    final List<_ActionItem> actions = <_ActionItem>[
      _ActionItem(
        emoji: '🔨',
        label: 'Zanaat',
        onTap: onNavigateCrafting,
        color: AppColors.warning,
      ),
      _ActionItem(
        emoji: '🛡️',
        label: 'Teçhizat',
        onTap: onNavigateEquipment,
        color: AppColors.accentBlue,
      ),
      _ActionItem(
        emoji: '🛒',
        label: 'Mağaza',
        onTap: onNavigateShop,
        color: AppColors.gold,
      ),
      _ActionItem(
        emoji: '🏦',
        label: 'Banka',
        onTap: onNavigateBank,
        color: AppColors.accentTeal,
      ),
      _ActionItem(
        emoji: '🏆',
        label: 'Sıralama',
        onTap: onNavigateLeaderboard,
        color: AppColors.accentPurple,
      ),
      _ActionItem(
        emoji: '🥊',
        label: 'PvP',
        onTap: onNavigatePvp,
        color: AppColors.danger,
      ),
      _ActionItem(
        emoji: '🏭',
        label: 'Tesis',
        onTap: onNavigateFacilities,
        color: AppColors.accentCyan,
      ),
      _ActionItem(
        emoji: '✨',
        label: 'Sezon',
        onTap: onNavigateSeason,
        color: AppColors.accentPurple,
      ),
    ];

    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: GridView.builder(
        itemCount: actions.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.88,
        ),
        itemBuilder: (context, index) {
          final _ActionItem item = actions[index];
          return GkkActionTile(
            emoji: item.emoji,
            label: item.label,
            onTap: item.onTap,
            accentColor: item.color,
          );
        },
      ),
      crossFadeState: expanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 240),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  final List<_ActivityItem> _activities = const <_ActivityItem>[
    _ActivityItem(
      icon: '⚔️',
      text: 'Karanlık Orman Zindanı tamamlandı',
      time: '5 dk',
    ),
    _ActivityItem(
      icon: '🛒',
      text: 'Demir Kılıç satın alındı — 2.500 altin',
      time: '18 dk',
    ),
    _ActivityItem(
      icon: '🔥',
      text: 'Levha +7 Başarılı Geliştirme',
      time: '1 s',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _activities.map((activity) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: GkkCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    color: AppColors.borderFaint,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    activity.icon,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    activity.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  activity.time,
                  style: AppTextStyles.micro.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.emoji,
    required this.value,
    required this.color,
    this.percent,
  });

  final String label;
  final String emoji;
  final String value;
  final Color color;
  final double? percent;
}

class _ActionItem {
  const _ActionItem({
    required this.emoji,
    required this.label,
    this.onTap,
    this.color,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
}

class _QuestItem {
  const _QuestItem({
    required this.id,
    required this.title,
    required this.progress,
    required this.goal,
    required this.icon,
  });

  final String id;
  final String title;
  final int progress;
  final int goal;
  final String icon;
}

class _ActivityItem {
  const _ActivityItem({
    required this.icon,
    required this.text,
    required this.time,
  });

  final String icon;
  final String text;
  final String time;
}

class _EquipmentStats {
  const _EquipmentStats({
    required this.attack,
    required this.defense,
    required this.hp,
    required this.luck,
  });

  final int attack;
  final int defense;
  final int hp;
  final int luck;

  double get powerFromEquipment => attack + defense + (hp / 10) + (luck * 2);
}

class _ReputationTier {
  const _ReputationTier({required this.title, required this.color});

  final String title;
  final Color color;
}

_EquipmentStats _calculateEquipmentStats(
  Map<String, InventoryItem?> equippedItems,
) {
  int attack = 0;
  int defense = 0;
  int hp = 0;
  int luck = 0;

  for (final item in equippedItems.values) {
    if (item == null) continue;
    attack += item.attack;
    defense += item.defense;
    hp += item.health;
    luck += item.luck;
  }

  return _EquipmentStats(attack: attack, defense: defense, hp: hp, luck: luck);
}

int _calculateTotalPower({
  required _EquipmentStats eqStats,
  required int level,
  required int reputation,
}) {
  final int equipmentPower = eqStats.powerFromEquipment.round();
  final int levelPower = level * 500;
  final int reputationPower = (reputation * 0.1).floor();
  return equipmentPower + levelPower + reputationPower;
}

_ReputationTier _getReputationTier(int reputation) {
  final int rep = reputation < 0 ? 0 : reputation;
  if (rep <= 5000) {
    return const _ReputationTier(title: 'Acemi', color: AppColors.rarityCommon);
  }
  if (rep <= 20000) {
    return const _ReputationTier(
      title: 'Tanınan',
      color: AppColors.rarityUncommon,
    );
  }
  if (rep <= 80000) {
    return const _ReputationTier(title: 'Saygın', color: AppColors.rarityRare);
  }
  if (rep <= 170000) {
    return const _ReputationTier(title: 'Ünlü', color: AppColors.rarityEpic);
  }
  if (rep <= 280000) {
    return const _ReputationTier(title: 'Efsanevi', color: AppColors.warning);
  }
  if (rep <= 356000) {
    return const _ReputationTier(title: 'Destansı', color: AppColors.danger);
  }
  return const _ReputationTier(title: 'İmparator', color: AppColors.gold);
}

bool _isFuture(String? value, DateTime now) {
  if (value == null || value.isEmpty) return false;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return false;
  return parsed.isAfter(now);
}

double _percent(int current, int max) {
  if (max <= 0) return 0;
  final double raw = current / max;
  if (raw < 0) return 0;
  if (raw > 1) return 1;
  return raw;
}

String _compact(int value) {
  final int abs = value.abs();
  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.toString();
}

String _gold(int value) {
  return '${_compact(value)} altin';
}

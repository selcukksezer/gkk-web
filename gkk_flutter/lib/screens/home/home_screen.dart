import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/common/gkk_action_tile.dart';
import '../../components/common/gkk_badge.dart';
import '../../components/common/gkk_card.dart';
import '../../components/common/gkk_progress_bar.dart';
import '../../components/common/gkk_section_header.dart';
import '../../components/common/gkk_stat_tile.dart';
import '../../components/layout/game_chrome.dart';
import '../../core/utils/power_formula.dart';
import '../../core/utils/xp_formula.dart';
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
  const _HomeErrorView({
    required this.message,
    required this.onRetry,
  });

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
  bool _showAllActions = false;

  @override
  Widget build(BuildContext context) {
    final PlayerProfile profile = widget.profile;
    final DateTime now = DateTime.now();

    final String displayName = (profile.displayName ?? profile.username).trim().isEmpty
        ? profile.username
        : (profile.displayName ?? profile.username);

    final bool inHospital = _isFuture(profile.hospitalUntil, now);
    final bool inPrison = _isFuture(profile.prisonUntil, now);
    final int energy = profile.energy;
    final int maxEnergy = profile.maxEnergy;
    final int tolerance = profile.tolerance;
    final int reputation = (profile.reputation ?? 0).clamp(0, 999999999);
    final XpProgress xpProgress = buildXpProgress(
      level: profile.level,
      totalXp: profile.xp,
    );

    final double xpPercent = xpProgress.percent;
    final double energyPercent = _percent(energy, maxEnergy);
    final double tolerancePercent = tolerance.clamp(0, 100) / 100;

    final int totalPower = calculateTotalPower(
      player: profile,
      equippedItems: widget.inventoryState.equippedItems.values,
    ).totalPower;
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
                colors: <Color>[AppColors.bgBase, AppColors.bgDeep],
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
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.md,
            AppSpacing.base,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            // Status banners
            _WarningStack(
              inHospital: inHospital,
              inPrison: inPrison,
              energy: energy,
              maxEnergy: maxEnergy,
              tolerance: tolerance,
            ),
            const SizedBox(height: AppSpacing.md),

            // Hero card
            _HeroSection(
              profile: profile,
              displayName: displayName,
              reputation: reputation,
              tier: tier,
              xpPercent: xpPercent,
              xpProgress: xpProgress,
            ),
            const SizedBox(height: AppSpacing.md),

            // Stats grid
            _StatsGrid(
              gold: profile.gold,
              gems: profile.gems,
              energy: energy,
              maxEnergy: maxEnergy,
              energyPercent: energyPercent,
              tolerance: tolerance,
              tolerancePercent: tolerancePercent,
              reputation: reputation,
              tier: tier,
              totalPower: totalPower,
            ),
            const SizedBox(height: AppSpacing.base),

            // Primary actions
            GkkSectionHeader(title: 'Hızlı Erişim'),
            const SizedBox(height: AppSpacing.sm),
            _PrimaryActions(
              inHospital: inHospital,
              inPrison: inPrison,
              onNavigateInventory: () => context.push(AppRoutes.inventory),
              onNavigateMarket: () => context.push(AppRoutes.market),
              onNavigateQuests: () => context.push(AppRoutes.quests),
              onComingSoon: _showComingSoon,
            ),
            const SizedBox(height: AppSpacing.base),

            // Active quests
            GkkSectionHeader(
              title: 'Aktif Görevler',
              trailing: TextButton(
                onPressed: () => context.push(AppRoutes.quests),
                child: const Text('Tümünü Gör'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _QuestSection(),
            const SizedBox(height: AppSpacing.base),

            // Potion action
            _PotionAction(
              potionCount: potionItems.length,
              onTap: () => _showPotionModal(context, potionItems, profile),
            ),
            const SizedBox(height: AppSpacing.base),

            // Secondary actions
            GkkSectionHeader(
              title: 'Tüm Özellikler',
              trailing: TextButton(
                onPressed: () => setState(() => _showAllActions = !_showAllActions),
                child: Text(_showAllActions ? '▲ Gizle' : '▼ Göster'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _SecondaryActions(
              expanded: _showAllActions,
              onToggle: () => setState(() => _showAllActions = !_showAllActions),
              onNavigateCrafting: () => context.push(AppRoutes.crafting),
              onNavigateEquipment: () => context.push(AppRoutes.inventory),
              onNavigateShop: () => context.push(AppRoutes.shop),
              onNavigateBank: () => context.push(AppRoutes.bank),
              onNavigateLeaderboard: () => context.push(AppRoutes.leaderboard),
              onNavigatePvp: () => context.push(AppRoutes.pvp),
              onNavigateFacilities: () => context.push(AppRoutes.facilities),
              onNavigateSeason: () => context.push(AppRoutes.season),
            ),
            const SizedBox(height: AppSpacing.base),

            // Recent activity
            GkkSectionHeader(title: 'Son Aktivite'),
            const SizedBox(height: AppSpacing.sm),
            const _RecentActivitySection(),
          ],
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
                Text('🧪 İksir Kullan', style: Theme.of(context).textTheme.titleLarge),
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
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                          ),
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                    content: Text(ok ? '${item.name} kullanıldı!' : '${item.name} kullanılamadı.'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _WarningStack extends StatelessWidget {
  const _WarningStack({
    required this.inHospital,
    required this.inPrison,
    required this.energy,
    required this.maxEnergy,
    required this.tolerance,
  });

  final bool inHospital;
  final bool inPrison;
  final int energy;
  final int maxEnergy;
  final int tolerance;

  @override
  Widget build(BuildContext context) {
    final List<Widget> banners = <Widget>[];

    if (inHospital || inPrison) {
      banners.add(
        _WarningBanner(
          icon: inHospital ? '🏥' : '👮',
            title: inHospital ? 'Hastanede Tedavi' : 'Cezaevinde',
          description: inHospital
              ? 'Tedavi süresi devam ediyor — Zindan ve PvP kısıtlandı'
              : 'Ceza süresi devam ediyor — Tüm aktiviteler kısıtlandı',
          color: inHospital ? AppColors.danger : AppColors.warning,
        ),
      );
    }

    if (energy < 20) {
      banners.add(
        _WarningBanner(
          icon: '⚡',
          title: 'Enerji Kritik',
          description: '$energy/$maxEnergy enerji kaldı — İksir kullanmayı düşün',
          color: AppColors.warning,
        ),
      );
    }

    if (tolerance > 60) {
      banners.add(
        _WarningBanner(
          icon: '⚠️',
          title: 'Yüksek Tolerans',
          description: '%$tolerance — İksir etkisi azalmakta',
          color: tolerance >= 80 ? AppColors.danger : AppColors.warning,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: banners
          .map((banner) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: banner,
              ))
          .toList(),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final String icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GkkCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      accentColor: color,
      borderGlow: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.bodyBold.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.profile,
    required this.displayName,
    required this.reputation,
    required this.tier,
    required this.xpPercent,
    required this.xpProgress,
  });

  final PlayerProfile profile;
  final String displayName;
  final int reputation;
  final _ReputationTier tier;
  final double xpPercent;
  final XpProgress xpProgress;

  String get _classEmoji => switch (profile.characterClass) {
        CharacterClass.warrior => '⚔️',
        CharacterClass.alchemist => '⚗️',
        CharacterClass.shadow => '🗡️',
        null => '🧙',
      };

  @override
  Widget build(BuildContext context) {
    return GkkCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      accentColor: AppColors.accentBlue,
      borderGlow: true,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[AppColors.bgCard, Color(0xFF111D38)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Avatar with gradient ring
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.accentPurple, AppColors.accentBlue],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.bgCard,
                  ),
                  alignment: Alignment.center,
                  child: Text(_classEmoji, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        if ((profile.guildName ?? '').trim().isNotEmpty)
                          GkkBadge(
                            text: '⚔️ ${profile.guildName}',
                            color: AppColors.accentPurple,
                            small: true,
                          ),
                        GkkBadge(
                          text: '${tier.title} • ${_compact(reputation)} Rep',
                          color: tier.color,
                          small: true,
                        ),
                        if (profile.globalSuspicionLevel > 60)
                          GkkBadge(
                            text: '⚠️ Şüphe ${profile.globalSuspicionLevel}%',
                            color: AppColors.warning,
                            small: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Level badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.7),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.goldGlow,
                      blurRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  '${xpProgress.level}',
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          GkkProgressBar(
            value: xpPercent,
            color: AppColors.accentBlue,
            height: 7,
            label: 'Deneyim',
            sublabel: '${_compact(xpProgress.xpInLevel)} / ${_compact(xpProgress.xpNeededInLevel)}',
          ),
        ],
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
      _StatItem(label: 'GOLD', emoji: '💰', value: _gold(gold), color: AppColors.gold),
      _StatItem(label: 'GEM', emoji: '💎', value: _compact(gems), color: AppColors.accentPurple),
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
      _StatItem(label: 'GÜÇ', emoji: '🔥', value: _compact(totalPower), color: AppColors.accentBlue),
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
        onTap: restricted ? null : () => onComingSoon('Koparma ekrani siradaki adimda acilacak.'),
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
    _QuestItem(id: 'q1', title: 'Demir Madeni', progress: 3, goal: 10, icon: '⛏️'),
    _QuestItem(id: 'q2', title: 'Karanlık Orman\'ı Temizle', progress: 1, goal: 3, icon: '🏰'),
    _QuestItem(id: 'q3', title: '5 İksir Kullan', progress: 2, goal: 5, icon: '🧪'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _quests.map((quest) {
        final double pct = quest.goal <= 0 ? 0 : (quest.progress / quest.goal).clamp(0.0, 1.0);
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
                      style: AppTextStyles.captionBold.copyWith(color: AppColors.accentBlue),
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
                    style: AppTextStyles.micro.copyWith(color: AppColors.textTertiary),
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
  const _PotionAction({
    required this.potionCount,
    required this.onTap,
  });

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
                  style: AppTextStyles.caption.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
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
      _ActionItem(emoji: '🔨', label: 'Zanaat', onTap: onNavigateCrafting, color: AppColors.warning),
      _ActionItem(emoji: '🛡️', label: 'Teçhizat', onTap: onNavigateEquipment, color: AppColors.accentBlue),
      _ActionItem(emoji: '🛒', label: 'Mağaza', onTap: onNavigateShop, color: AppColors.gold),
      _ActionItem(emoji: '🏦', label: 'Banka', onTap: onNavigateBank, color: AppColors.accentTeal),
      _ActionItem(emoji: '🏆', label: 'Sıralama', onTap: onNavigateLeaderboard, color: AppColors.accentPurple),
      _ActionItem(emoji: '🥊', label: 'PvP', onTap: onNavigatePvp, color: AppColors.danger),
      _ActionItem(emoji: '🏭', label: 'Tesis', onTap: onNavigateFacilities, color: AppColors.accentCyan),
      _ActionItem(emoji: '✨', label: 'Sezon', onTap: onNavigateSeason, color: AppColors.accentPurple),
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
      crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 240),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  final List<_ActivityItem> _activities = const <_ActivityItem>[
    _ActivityItem(icon: '⚔️', text: 'Karanlık Orman Zindanı tamamlandı', time: '5 dk'),
    _ActivityItem(icon: '🛒', text: 'Demir Kılıç satın alındı — 2.500 altin', time: '18 dk'),
    _ActivityItem(icon: '🔥', text: 'Levha +7 Başarılı Geliştirme', time: '1 s'),
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
                  child: Text(activity.icon, style: const TextStyle(fontSize: 18)),
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
                  style: AppTextStyles.micro.copyWith(color: AppColors.textTertiary),
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

class _ReputationTier {
  const _ReputationTier({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;
}

_ReputationTier _getReputationTier(int reputation) {
  final int rep = reputation < 0 ? 0 : reputation;
  if (rep <= 5000) {
    return const _ReputationTier(title: 'Acemi', color: AppColors.rarityCommon);
  }
  if (rep <= 20000) {
    return const _ReputationTier(title: 'Tanınan', color: AppColors.rarityUncommon);
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

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
    final int tolerance = profile.addictionLevel;
    final int reputation = (profile.reputation ?? 0).clamp(0, 999999999);

    final double xpPercent = _percent(profile.xp, 1000);
    final double energyPercent = _percent(energy, maxEnergy);
    final double tolerancePercent = tolerance.clamp(0, 100) / 100;

    final _EquipmentStats eqStats = _calculateEquipmentStats(widget.inventoryState.equippedItems);
    final int totalPower = _calculateTotalPower(eqStats: eqStats, level: profile.level, reputation: reputation);
    final _ReputationTier tier = _getReputationTier(reputation);

    final List<InventoryItem> potionItems = widget.inventoryState.items
        .where((item) => item.itemType == ItemType.potion && item.quantity > 0)
        .toList();

    return Stack(
      children: <Widget>[
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFF0F172A),
                  Color(0xFF04060C),
                  Color(0xFF000000),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -220,
          left: -160,
          child: IgnorePointer(
            child: Container(
              width: 520,
              height: 520,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x553B82F6), Color(0x003B82F6)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -240,
          right: -170,
          child: IgnorePointer(
            child: Container(
              width: 560,
              height: 560,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x4434D399), Color(0x0034D399)],
                ),
              ),
            ),
          ),
        ),
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: <Widget>[
            _WarningStack(
              inHospital: inHospital,
              inPrison: inPrison,
              energy: energy,
              maxEnergy: maxEnergy,
              tolerance: tolerance,
            ),
            const SizedBox(height: 10),
            _HeroSection(
              profile: profile,
              displayName: displayName,
              reputation: reputation,
              tier: tier,
              xpPercent: xpPercent,
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            _PrimaryActions(
              inHospital: inHospital,
              inPrison: inPrison,
              onNavigateInventory: () => context.push(AppRoutes.inventory),
              onNavigateMarket: () => context.push(AppRoutes.market),
              onComingSoon: _showComingSoon,
            ),
            const SizedBox(height: 14),
            const _QuestSection(),
            const SizedBox(height: 14),
            _PotionAction(
              potionCount: potionItems.length,
              onTap: () => _showPotionModal(context, potionItems, profile),
            ),
            const SizedBox(height: 12),
            _SecondaryActions(
              expanded: _showAllActions,
              onToggle: () {
                setState(() {
                  _showAllActions = !_showAllActions;
                });
              },
              onNavigateFacilities: () => context.push(AppRoutes.facilities),
              onComingSoon: _showComingSoon,
            ),
            const SizedBox(height: 14),
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showComingSoon('İksir kullanma akışının mobil RPC bağlantısı bir sonraki adımda.');
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
          color: inHospital ? Colors.red : Colors.orange,
        ),
      );
    }

    if (energy < 20) {
      banners.add(
        _WarningBanner(
          icon: '⚡',
          title: 'Enerji Kritik',
          description: '$energy/$maxEnergy enerji kaldı — İksir kullanmayı düşün',
          color: Colors.amber,
        ),
      );
    }

    if (tolerance > 60) {
      banners.add(
        _WarningBanner(
          icon: '⚠️',
          title: 'Yüksek Tolerans',
          description: '%$tolerance — İksir etkisi azalmakta',
          color: tolerance >= 80 ? Colors.red : Colors.orange,
        ),
      );
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: banners
          .map((banner) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
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
  });

  final PlayerProfile profile;
  final String displayName;
  final int reputation;
  final _ReputationTier tier;
  final double xpPercent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45)),
                ),
                alignment: Alignment.center,
                child: const Text('🧙', style: TextStyle(fontSize: 36)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        if ((profile.guildName ?? '').trim().isNotEmpty)
                          _MiniBadge(text: '⚔️ ${profile.guildName}', color: Colors.deepPurple),
                        _MiniBadge(text: '👑 ${tier.title} • ${_compact(reputation)} Rep', color: tier.color),
                        _MiniBadge(
                          text: profile.globalSuspicionLevel > 60
                              ? '🌟 Şüphe: ${profile.globalSuspicionLevel}%'
                              : '🌟 Güvenli',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${profile.level}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Experience', style: Theme.of(context).textTheme.labelMedium),
              Text('${_compact(profile.xp)} / 1.000', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: xpPercent),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    final stats = <_StatItem>[
      _StatItem(label: 'Gold', emoji: '💰', value: _gold(gold), color: Colors.amber),
      _StatItem(label: 'Gems', emoji: '💎', value: _compact(gems), color: Colors.purpleAccent),
      _StatItem(
        label: 'Energy',
        emoji: '⚡',
        value: '$energy/$maxEnergy',
        color: Colors.cyan,
        percent: energyPercent,
      ),
      _StatItem(
        label: 'Tolerance',
        emoji: '🧪',
        value: '$tolerance%',
        color: Colors.deepOrange,
        percent: tolerancePercent,
      ),
      _StatItem(
        label: 'Reputation',
        emoji: '⭐',
        value: '${_compact(reputation)} (${tier.title})',
        color: tier.color,
      ),
      _StatItem(label: 'Power', emoji: '🔥', value: _compact(totalPower), color: Colors.indigoAccent),
    ];

    return GridView.builder(
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) => _StatCard(stat: stats[index]),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _StatItem stat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stat.color.withValues(alpha: 0.4)),
        color: stat.color.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(stat.emoji, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              Text(stat.label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const Spacer(),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (stat.percent != null) ...<Widget>[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: stat.percent),
          ],
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions({
    required this.inHospital,
    required this.inPrison,
    required this.onNavigateInventory,
    required this.onNavigateMarket,
    required this.onComingSoon,
  });

  final bool inHospital;
  final bool inPrison;
  final VoidCallback onNavigateInventory;
  final VoidCallback onNavigateMarket;
  final void Function(String message) onComingSoon;

  @override
  Widget build(BuildContext context) {
    final bool restricted = inHospital || inPrison;
    final actions = <_ActionItem>[
      _ActionItem(
        emoji: '⚔️',
        label: 'Koparma',
        onTap: restricted ? null : () => onComingSoon('Koparma ekrani siradaki adimda acilacak.'),
      ),
      _ActionItem(
        emoji: '📜',
        label: 'Görevler',
        onTap: () => onComingSoon('Görevler sayfası sıradaki adımda taşınacak.'),
      ),
      _ActionItem(
        emoji: '💰',
        label: 'Market',
        onTap: onNavigateMarket,
      ),
      _ActionItem(
        emoji: '🔥',
        label: 'Geliştirme',
        onTap: onNavigateInventory,
      ),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        final bool enabled = item.onTap != null;
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              color: enabled
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                  : Theme.of(context).disabledColor.withValues(alpha: 0.1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(item.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('🎯 Aktif Görevler', style: Theme.of(context).textTheme.titleMedium),
            TextButton(onPressed: () {}, child: const Text('Tümünü Gör')),
          ],
        ),
        const SizedBox(height: 6),
        ..._quests.map((quest) {
          final double pct = quest.goal <= 0 ? 0 : (quest.progress / quest.goal).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.35)),
              color: Colors.blue.withValues(alpha: 0.1),
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(quest.icon),
                    const SizedBox(width: 8),
                    Expanded(child: Text(quest.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${(pct * 100).round()}%'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: pct),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${quest.progress}/${quest.goal} completed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
          color: Colors.green.withValues(alpha: 0.15),
        ),
        child: Row(
          children: <Widget>[
            const Text('🧪', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('İksir Kullan', style: Theme.of(context).textTheme.titleSmall),
                  Text('$potionCount mevcut • Enerji yenile', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({
    required this.expanded,
    required this.onToggle,
    required this.onNavigateFacilities,
    required this.onComingSoon,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onNavigateFacilities;
  final void Function(String message) onComingSoon;

  @override
  Widget build(BuildContext context) {
    final actions = <_ActionItem>[
      _ActionItem(emoji: '🔨', label: 'Zanaat', onTap: () => onComingSoon('Zanaat sayfasi tasinacak.')),
      _ActionItem(emoji: '🛡️', label: 'Teçhizat', onTap: () => onComingSoon('Teçhizat sayfası taşınacak.')),
      _ActionItem(emoji: '🛒', label: 'Mağaza', onTap: () => onComingSoon('Mağaza sayfası taşınacak.')),
      _ActionItem(emoji: '🏦', label: 'Banka', onTap: () => onComingSoon('Banka sayfası taşınacak.')),
      _ActionItem(emoji: '🏆', label: 'Sıralama', onTap: () => onComingSoon('Sıralama sayfası taşınacak.')),
      _ActionItem(emoji: '🥊', label: 'PvP', onTap: () => onComingSoon('PvP sayfası taşınacak.')),
      _ActionItem(emoji: '🏭', label: 'Tesis', onTap: onNavigateFacilities),
      _ActionItem(emoji: '✨', label: 'Sezon', onTap: () => onComingSoon('Sezon sayfası taşınacak.')),
    ];

    return Column(
      children: <Widget>[
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: GridView.builder(
            itemCount: actions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final item = actions[index];
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(item.emoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 6),
                      Text(item.label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ),
                ),
              );
            },
          ),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
        TextButton(
          onPressed: onToggle,
          child: Text(expanded ? '▲ Daha Az Göster' : '▼ Tüm Özellikler'),
        ),
      ],
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  final List<_ActivityItem> _activities = const <_ActivityItem>[
    _ActivityItem(icon: '⚔️', text: 'Karanlık Orman Zindanı tamamlandı', time: '5 dk'),
    _ActivityItem(icon: '🛒', text: 'Demir Kılıç satın alındı — 2.500 🪙', time: '18 dk'),
    _ActivityItem(icon: '🔥', text: 'Levha +7 Başarılı Geliştirme', time: '1 s'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('⏱️ Son Aktivite', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._activities.map((activity) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
            ),
            child: Row(
              children: <Widget>[
                Text(activity.icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Text(activity.text, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(activity.time, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }),
      ],
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
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;
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
  const _ReputationTier({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;
}

_EquipmentStats _calculateEquipmentStats(Map<String, InventoryItem?> equippedItems) {
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

  return _EquipmentStats(
    attack: attack,
    defense: defense,
    hp: hp,
    luck: luck,
  );
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
    return const _ReputationTier(title: 'Acemi', color: Colors.grey);
  }
  if (rep <= 20000) {
    return const _ReputationTier(title: 'Taninan', color: Colors.green);
  }
  if (rep <= 80000) {
    return const _ReputationTier(title: 'Saygin', color: Colors.blue);
  }
  if (rep <= 170000) {
    return const _ReputationTier(title: 'Unlu', color: Colors.purple);
  }
  if (rep <= 280000) {
    return const _ReputationTier(title: 'Efsanevi', color: Colors.orange);
  }
  if (rep <= 356000) {
    return const _ReputationTier(title: 'Destansi', color: Colors.red);
  }
  return const _ReputationTier(title: 'Imparator', color: Colors.amber);
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

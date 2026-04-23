import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/player_model.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../screens/chat/chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GameTopBar
// ─────────────────────────────────────────────────────────────────────────────

class GameTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const GameTopBar({super.key, required this.title, this.onLogout});

  final String title;
  final Future<void> Function()? onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    final String displayName = profile == null
        ? 'Oyuncu'
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));

    final int level = profile?.level ?? 1;
    final int energy = profile?.energy ?? 0;
    final int maxEnergy = profile?.maxEnergy ?? 100;
    final int gold = profile?.gold ?? 0;
    final int gems = profile?.gems ?? 0;
    final double xpPercent = _xpPercent(profile?.xp ?? 0, 1000);
    final bool hasDrawerLogout = onLogout != null;

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 12,
      title: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              color: AppColors.chromeBg,
              border: Border.all(color: AppColors.chromeBorder),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Builder(
                  builder: (ctx) => IconButton(
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    icon: const Icon(Icons.menu_rounded, size: 22),
                    tooltip: hasDrawerLogout
                        ? 'Menü (Çıkış için menüyü kullan)'
                        : 'Menü',
                    color: AppColors.accentBlue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                // Level badge
                _LevelBadge(level: level),
                const SizedBox(width: AppSpacing.sm),
                // Name + XP bar
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _XpBar(percent: xpPercent),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _ResourceChip(
                            icon: Icons.flash_on_rounded,
                            value: '$energy/$maxEnergy',
                            color: AppColors.accentCyan,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ResourceChip(
                            icon: Icons.paid_rounded,
                            value: _compact(gold),
                            color: AppColors.gold,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _ResourceChip(
                            icon: Icons.diamond_rounded,
                            value: _compact(gems),
                            color: AppColors.accentPurple,
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
      ),
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
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
            blurRadius: 10,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$level',
        style: AppTextStyles.micro.copyWith(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.percent});
  final double percent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Stack(
        children: <Widget>[
          Container(
            height: 3,
            color: AppColors.accentBlue.withValues(alpha: 0.15),
          ),
          FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.accentPurple, AppColors.accentBlue],
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.55),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameDrawer
// ─────────────────────────────────────────────────────────────────────────────

class GameDrawer extends ConsumerWidget {
  const GameDrawer({super.key, this.onLogout});

  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(playerProvider).profile;
    final String displayName = profile == null
        ? 'Oyuncu'
        : ((profile.displayName ?? profile.username).trim().isEmpty
              ? profile.username
              : (profile.displayName ?? profile.username));
    final int level = profile?.level ?? 1;
    final int gold = profile?.gold ?? 0;
    final int gems = profile?.gems ?? 0;

    return Drawer(
      child: Column(
        children: <Widget>[
          // ── Header ──────────────────────────────────────────────────────
          _DrawerHeader(
            displayName: displayName,
            level: level,
            gold: gold,
            gems: gems,
            characterClass: profile?.characterClass,
          ),
          // ── Nav items ───────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                _navItem(
                  context,
                  icon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  route: AppRoutes.home,
                ),
                _sectionHeader('KARAKTER'),
                _navItem(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: 'Karakter',
                  route: AppRoutes.character,
                ),
                _navItem(
                  context,
                  icon: Icons.emoji_events_outlined,
                  label: 'Başarımlar',
                  route: AppRoutes.achievements,
                ),
                _navItem(
                  context,
                  icon: Icons.stars_outlined,
                  label: 'İtibar',
                  route: AppRoutes.reputation,
                ),
                _sectionHeader('SAVAŞ'),
                _navItem(
                  context,
                  icon: Icons.shield_moon_outlined,
                  label: 'Zindan',
                  route: AppRoutes.dungeon,
                ),
                _navItem(
                  context,
                  icon: Icons.sports_kabaddi_rounded,
                  label: 'PvP',
                  route: AppRoutes.pvp,
                ),
                _navItem(
                  context,
                  icon: Icons.leaderboard_rounded,
                  label: 'Sıralama',
                  route: AppRoutes.leaderboard,
                ),
                _navItem(
                  context,
                  icon: Icons.ac_unit_rounded,
                  label: 'Mevsim',
                  route: AppRoutes.season,
                ),
                _sectionHeader('LONCA'),
                _navItem(
                  context,
                  icon: Icons.groups_outlined,
                  label: 'Lonca',
                  route: AppRoutes.guild,
                ),
                _navItem(
                  context,
                  icon: Icons.flag_outlined,
                  label: 'Lonca Savaşı',
                  route: AppRoutes.guildWar,
                ),
                _navItem(
                  context,
                  icon: Icons.account_balance_outlined,
                  label: 'Anıt',
                  route: AppRoutes.guildMonument,
                ),
                _sectionHeader('EKONOMİ'),
                _navItem(
                  context,
                  icon: Icons.storefront_outlined,
                  label: 'Pazar',
                  route: AppRoutes.market,
                ),
                _navItem(
                  context,
                  icon: Icons.shopping_bag_outlined,
                  label: 'Mağaza',
                  route: AppRoutes.shop,
                ),
                _navItem(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Banka',
                  route: AppRoutes.bank,
                ),
                _navItem(
                  context,
                  icon: Icons.swap_horiz_rounded,
                  label: 'Ticaret',
                  route: AppRoutes.trade,
                ),
                _sectionHeader('ÜRETİM'),
                _navItem(
                  context,
                  icon: Icons.handyman_outlined,
                  label: 'Zanaat',
                  route: AppRoutes.crafting,
                ),
                _navItem(
                  context,
                  icon: Icons.auto_fix_high_outlined,
                  label: 'Güçlendirme',
                  route: AppRoutes.enhancement,
                ),
                _navItem(
                  context,
                  icon: Icons.construction_outlined,
                  label: 'İnşaat',
                  route: AppRoutes.building,
                ),
                _navItem(
                  context,
                  icon: Icons.factory_outlined,
                  label: 'Tesisler',
                  route: AppRoutes.facilities,
                ),
                _sectionHeader('DÜNYA'),
                _navItem(
                  context,
                  icon: Icons.map_outlined,
                  label: 'Harita',
                  route: AppRoutes.map,
                ),
                _navItem(
                  context,
                  icon: Icons.location_city_outlined,
                  label: 'Mekanlar',
                  route: AppRoutes.mekans,
                ),
                _navItem(
                  context,
                  icon: Icons.event_outlined,
                  label: 'Etkinlikler',
                  route: AppRoutes.events,
                ),
                _navItem(
                  context,
                  icon: Icons.task_alt_rounded,
                  label: 'Görevler',
                  route: AppRoutes.quests,
                ),
                _sectionHeader('DİĞER'),
                _navItem(
                  context,
                  icon: Icons.local_hospital_outlined,
                  label: 'Hastane',
                  route: AppRoutes.hospital,
                ),
                _navItem(
                  context,
                  icon: Icons.gavel_rounded,
                  label: 'Hapishane',
                  route: AppRoutes.prison,
                ),
                _navItem(
                  context,
                  icon: Icons.chat_outlined,
                  label: 'Sohbet',
                  route: AppRoutes.chat,
                ),
                _navItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Ayarlar',
                  route: AppRoutes.settings,
                ),
              ],
            ),
          ),
          // ── Footer ──────────────────────────────────────────────────────
          const Divider(height: 1, color: AppColors.borderFaint),
          if (onLogout != null)
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: AppColors.danger,
              ),
              title: const Text(
                'Çıkış Yap',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                await onLogout!.call();
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textTertiary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      ),
      onTap: () {
        Navigator.of(context).pop();
        if (route == AppRoutes.chat) {
          showChatModal(context);
        } else if (route == AppRoutes.home) {
          context.go(route);
        } else {
          context.push(route);
        }
      },
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.displayName,
    required this.level,
    required this.gold,
    required this.gems,
    this.characterClass,
  });

  final String displayName;
  final int level;
  final int gold;
  final int gems;
  final CharacterClass? characterClass;

  String get _classEmoji => switch (characterClass) {
    CharacterClass.warrior => '⚔️',
    CharacterClass.alchemist => '⚗️',
    CharacterClass.shadow => '🗡️',
    null => '🧙',
  };

  String get _classLabel => switch (characterClass) {
    CharacterClass.warrior => 'Savaşçı',
    CharacterClass.alchemist => 'Simyacı',
    CharacterClass.shadow => 'Gölge',
    null => 'Karakter',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        MediaQuery.of(context).padding.top + AppSpacing.base,
        AppSpacing.base,
        AppSpacing.base,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF121B33), AppColors.bgSurface],
        ),
        border: Border(bottom: BorderSide(color: AppColors.borderFaint)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Avatar + level
          Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.accentPurple,
                      AppColors.accentBlue,
                    ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.accentBlue.withValues(alpha: 0.4),
                      blurRadius: 14,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(_classEmoji, style: const TextStyle(fontSize: 26)),
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
                      style: AppTextStyles.titleBold,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _classLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Level bubble
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  color: AppColors.gold.withValues(alpha: 0.18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  'Lv.$level',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Quick resource row
          Row(
            children: <Widget>[
              _QuickResource(
                icon: Icons.paid_rounded,
                value: _compact(gold),
                color: AppColors.gold,
              ),
              const SizedBox(width: AppSpacing.sm),
              _QuickResource(
                icon: Icons.diamond_rounded,
                value: _compact(gems),
                color: AppColors.accentPurple,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickResource extends StatelessWidget {
  const _QuickResource({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GameBottomBar  (animated active indicator)
// ─────────────────────────────────────────────────────────────────────────────

class GameBottomBar extends StatefulWidget {
  const GameBottomBar({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  State<GameBottomBar> createState() => _GameBottomBarState();
}

class _GameBottomBarState extends State<GameBottomBar>
    with SingleTickerProviderStateMixin {
  static const List<_BottomItem> _items = <_BottomItem>[
    _BottomItem(path: AppRoutes.home, label: 'Home', icon: Icons.home_rounded),
    _BottomItem(
      path: AppRoutes.inventory,
      label: 'Envanter',
      icon: Icons.inventory_2_rounded,
    ),
    _BottomItem(
      path: AppRoutes.dungeon,
      label: 'Zindan',
      icon: Icons.sports_martial_arts_rounded,
    ),
    _BottomItem(
      path: AppRoutes.character,
      label: 'Karakter',
      icon: Icons.bolt_rounded,
    ),
    _BottomItem(
      path: AppRoutes.profile,
      label: 'Profil',
      icon: Icons.person_rounded,
    ),
  ];

  late final AnimationController _indicatorCtrl;
  late Animation<double> _indicatorAnim;

  int _activeIndex(String route) {
    for (int i = 0; i < _items.length; i++) {
      if (_matches(route, _items[i].path)) return i;
    }
    return 0;
  }

  bool _matches(String current, String route) {
    if (current == route) return true;
    if (route == AppRoutes.home) return current == AppRoutes.home;
    return current.startsWith(route);
  }

  @override
  void initState() {
    super.initState();
    final int initial = _activeIndex(widget.currentRoute);
    _indicatorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _indicatorAnim =
        Tween<double>(
          begin: initial.toDouble(),
          end: initial.toDouble(),
        ).animate(
          CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
        );
  }

  @override
  void didUpdateWidget(GameBottomBar old) {
    super.didUpdateWidget(old);
    if (old.currentRoute != widget.currentRoute) {
      final int newIdx = _activeIndex(widget.currentRoute);
      _indicatorAnim =
          Tween<double>(
            begin: _indicatorAnim.value,
            end: newIdx.toDouble(),
          ).animate(
            CurvedAnimation(parent: _indicatorCtrl, curve: Curves.easeOutCubic),
          );
      _indicatorCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _indicatorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int activeIdx = _activeIndex(widget.currentRoute);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.chromeBg,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
                      border: Border.all(color: AppColors.chromeBorder),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double itemW =
                            constraints.maxWidth / _items.length;
                        return Stack(
                          children: <Widget>[
                            // Animated active indicator pill
                            AnimatedBuilder(
                              animation: _indicatorAnim,
                              builder: (context, _) {
                                return Positioned(
                                  top: 8,
                                  left:
                                      _indicatorAnim.value * itemW +
                                      itemW * 0.15,
                                  width: itemW * 0.70,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMd,
                                      ),
                                      color: AppColors.accentBlue.withValues(
                                        alpha: 0.18,
                                      ),
                                      border: Border.all(
                                        color: AppColors.accentBlue.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Tap targets + labels
                            Row(
                              children: List<Widget>.generate(_items.length, (
                                i,
                              ) {
                                final _BottomItem item = _items[i];
                                final bool isActive = i == activeIdx;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (item.path == widget.currentRoute) {
                                        return;
                                      }
                                      if (item.path == AppRoutes.home) {
                                        context.go(item.path);
                                      } else {
                                        context.push(item.path);
                                      }
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: <Widget>[
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            item.icon,
                                            size: isActive ? 22 : 20,
                                            color: isActive
                                                ? AppColors.accentBlue
                                                : AppColors.textTertiary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          style: AppTextStyles.micro.copyWith(
                                            color: isActive
                                                ? AppColors.accentBlue
                                                : AppColors.textTertiary,
                                            fontWeight: isActive
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                            fontSize: 9,
                                          ),
                                          child: Text(item.label),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(right: 6, top: 0, child: GameChatFab()),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helpers
// ─────────────────────────────────────────────────────────────────────────────

class _BottomItem {
  const _BottomItem({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        color: color.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textPrimary,
              fontSize: 10,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

double _xpPercent(int xp, int nextLevelXp) {
  if (nextLevelXp <= 0) return 0;
  return (xp / nextLevelXp).clamp(0.0, 1.0);
}

String _compact(int value) {
  final int abs = value.abs();
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat modal & FAB
// ─────────────────────────────────────────────────────────────────────────────

/// Web FloatingChat'ın Flutter karşılığı — bottom sheet olarak açılır.
void showChatModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    builder: (BuildContext ctx) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1117),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Color(0x1AFFFFFF)),
              left: BorderSide(color: Color(0x1AFFFFFF)),
              right: BorderSide(color: Color(0x1AFFFFFF)),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: const ChatScreen(asPanel: true),
        ),
      );
    },
  );
}

/// Web FloatingChat butonunun Flutter karşılığı.
class GameChatFab extends StatefulWidget {
  const GameChatFab({super.key});

  @override
  State<GameChatFab> createState() => _GameChatFabState();
}

class _GameChatFabState extends State<GameChatFab> {
  int _unreadCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadUnreadCount(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final dynamic res = await SupabaseService.client.rpc(
        'get_dm_conversations',
      );
      final List<dynamic> rows = (res as List?) ?? const <dynamic>[];

      int total = 0;
      for (final dynamic row in rows) {
        if (row is Map) {
          total += ((row['unread_count'] as num?) ?? 0).toInt();
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _unreadCount = total.clamp(0, 99);
      });
    } catch (_) {
      // Fail silently; chat badge is non-critical UI info.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _unreadCount = 0);
        showChatModal(context);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.chat_bubble_rounded,
                  color: Color(0xFF7DD3FC),
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  'Sohbet',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Color(0xFAF97316), Color(0xFAC2410C)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x70FBBF24)),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFF0E0),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

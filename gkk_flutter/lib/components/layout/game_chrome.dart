import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class GameTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const GameTopBar({
    super.key,
    required this.title,
    this.onLogout,
  });

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

    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 12,
      title: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xCC070914),
              border: Border.all(color: const Color(0x5C5296FF)),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x8C000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            child: Row(
              children: <Widget>[
                Builder(
                  builder: (context) {
                    return IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'Menü',
                      color: const Color(0xC8649BFF),
                    );
                  },
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xE45A32DC), Color(0xCC3C5AFF)],
                    ),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Color(0x995064FF), blurRadius: 8),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$level',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xE8B9D2FF)),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          value: xpPercent,
                          backgroundColor: const Color(0x59324B8C),
                        ),
                      ),
                    ],
                  ),
                ),
                _ResourceChip(icon: Icons.flash_on_rounded, value: '$energy/$maxEnergy', color: const Color(0xE600D7D7)),
                const SizedBox(width: 6),
                _ResourceChip(icon: Icons.paid_rounded, value: _compact(gold), color: const Color(0xE6DDB200)),
                const SizedBox(width: 6),
                _ResourceChip(icon: Icons.diamond_rounded, value: _compact(gems), color: const Color(0xE6C34BFF)),
                if (onLogout != null) ...<Widget>[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Çıkış Yap',
                  ),
                ],
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

class GameDrawer extends StatelessWidget {
  const GameDrawer({
    super.key,
    this.onLogout,
  });

  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.home_rounded),
                    title: const Text('Ana Sayfa'),
                    onTap: () => _go(context, AppRoutes.home),
                  ),
            _sectionHeader('KARAKTER'),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Karakter'),
              onTap: () => _go(context, AppRoutes.character),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Başarımlar'),
              onTap: () => _go(context, AppRoutes.achievements),
            ),
            ListTile(
              leading: const Icon(Icons.stars_outlined),
              title: const Text('İtibar'),
              onTap: () => _go(context, AppRoutes.reputation),
            ),
            _sectionHeader('SAVAŞ'),
            ListTile(
              leading: const Icon(Icons.shield_moon_outlined),
              title: const Text('Zindan'),
              onTap: () => _go(context, AppRoutes.dungeon),
            ),
            ListTile(
              leading: const Icon(Icons.sports_kabaddi_rounded),
              title: const Text('PvP'),
              onTap: () => _go(context, AppRoutes.pvp),
            ),
            ListTile(
              leading: const Icon(Icons.leaderboard_rounded),
              title: const Text('Sıralama'),
              onTap: () => _go(context, AppRoutes.leaderboard),
            ),
            ListTile(
              leading: const Icon(Icons.ac_unit_rounded),
              title: const Text('Mevsim'),
              onTap: () => _go(context, AppRoutes.season),
            ),
            _sectionHeader('LONCA'),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Lonca'),
              onTap: () => _go(context, AppRoutes.guild),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Lonca Savaşı'),
              onTap: () => _go(context, AppRoutes.guildWar),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Anıt'),
              onTap: () => _go(context, AppRoutes.guildMonument),
            ),
            _sectionHeader('EKONOMİ'),
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Pazar'),
              onTap: () => _go(context, AppRoutes.market),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: const Text('Mağaza'),
              onTap: () => _go(context, AppRoutes.shop),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Banka'),
              onTap: () => _go(context, AppRoutes.bank),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Ticaret'),
              onTap: () => _go(context, AppRoutes.trade),
            ),
            _sectionHeader('ÜRETİM'),
            ListTile(
              leading: const Icon(Icons.handyman_outlined),
              title: const Text('El Sanatları'),
              onTap: () => _go(context, AppRoutes.crafting),
            ),
            ListTile(
              leading: const Icon(Icons.auto_fix_high_outlined),
              title: const Text('Güçlendirme'),
              onTap: () => _go(context, AppRoutes.enhancement),
            ),
            ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: const Text('İnşaat'),
              onTap: () => _go(context, AppRoutes.building),
            ),
            ListTile(
              leading: const Icon(Icons.factory_outlined),
              title: const Text('Tesisler'),
              onTap: () => _go(context, AppRoutes.facilities),
            ),
            _sectionHeader('DÜNYA'),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Harita'),
              onTap: () => _go(context, AppRoutes.map),
            ),
            ListTile(
              leading: const Icon(Icons.location_city_outlined),
              title: const Text('Mekanlar'),
              onTap: () => _go(context, AppRoutes.mekans),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Etkinlikler'),
              onTap: () => _go(context, AppRoutes.events),
            ),
            ListTile(
              leading: const Icon(Icons.task_alt_rounded),
              title: const Text('Görevler'),
              onTap: () => _go(context, AppRoutes.quests),
            ),
            _sectionHeader('DİĞER'),
            ListTile(
              leading: const Icon(Icons.local_hospital_outlined),
              title: const Text('Hastane'),
              onTap: () => _go(context, AppRoutes.hospital),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_rounded),
              title: const Text('Hapishane'),
              onTap: () => _go(context, AppRoutes.prison),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Sohbet'),
              onTap: () => _go(context, AppRoutes.chat),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Ayarlar'),
              onTap: () => _go(context, AppRoutes.settings),
            ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (onLogout != null)
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Çıkış Yap'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await onLogout!.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return ListTile(
      dense: true,
      enabled: false,
      title: Text(
        title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white38),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.of(context).pop();
    context.go(route);
  }
}

class GameBottomBar extends StatelessWidget {
  const GameBottomBar({
    super.key,
    required this.currentRoute,
  });

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final List<_BottomItem> items = <_BottomItem>[
      const _BottomItem(path: AppRoutes.home, label: 'Home', icon: Icons.home_rounded),
      const _BottomItem(path: AppRoutes.inventory, label: 'Inventory', icon: Icons.inventory_2_rounded),
      const _BottomItem(path: AppRoutes.dungeon, label: 'Dungeon', icon: Icons.sports_martial_arts_rounded),
      const _BottomItem(path: AppRoutes.character, label: 'Skills', icon: Icons.bolt_rounded),
      const _BottomItem(path: AppRoutes.profile, label: 'Profile', icon: Icons.person_rounded),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xBC070914),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0x5C5296FF)),
            ),
            child: Row(
              children: items.map((item) {
                final bool isActive = _matches(currentRoute, item.path);
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      context.go(item.path);
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          item.icon,
                          size: 22,
                          color: isActive ? const Color(0xFFA8D6FF) : const Color(0xCC5570A2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: isActive ? const Color(0xD6A8D6FF) : const Color(0xAA4B6496),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  bool _matches(String current, String route) {
    if (current == route) return true;
    if (route == AppRoutes.home) return current == AppRoutes.home;
    return current.startsWith(route);
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

double _xpPercent(int xp, int nextLevelXp) {
  if (nextLevelXp <= 0) return 0;
  final value = xp / nextLevelXp;
  if (value < 0) return 0;
  if (value > 1) return 1;
  return value;
}

String _compact(int value) {
  final int abs = value.abs();
  if (abs >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toString();
}

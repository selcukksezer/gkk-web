import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/guild_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/guild_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
String _roleLabel(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 'Lider';
    case GuildRole.officer:
      return 'Subay';
    case GuildRole.member:
      return 'Üye';
  }
}

String _roleEmoji(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return '👑';
    case GuildRole.officer:
      return '⭐';
    case GuildRole.member:
      return '🛡️';
  }
}

int _roleSortOrder(GuildRole role) {
  switch (role) {
    case GuildRole.leader:
      return 0;
    case GuildRole.officer:
      return 1;
    case GuildRole.member:
      return 2;
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class GuildScreen extends ConsumerStatefulWidget {
  const GuildScreen({super.key});

  @override
  ConsumerState<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends ConsumerState<GuildScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();
  final TextEditingController _createDescController = TextEditingController();
  bool _memberActionLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(playerProvider.notifier).loadProfile();
      await ref.read(guildProvider.notifier).loadGuild();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _createNameController.dispose();
    _createDescController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    await ref.read(guildProvider.notifier).searchGuilds(query);
  }

  Future<void> _joinGuild(String guildId) async {
    final ok = await ref.read(guildProvider.notifier).joinGuild(guildId);
    if (!ok) {
      final err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
    }
  }

  Future<void> _leaveGuild() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Loncadan Ayrıl'),
        content: const Text('Loncadan ayrılmak istediğinize emin misiniz?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ref.read(guildProvider.notifier).leaveGuild();
    if (!ok) {
      final err = ref.read(guildProvider).error;
      if (err != null) _showSnack(err);
    }
  }

  Future<void> _showCreateDialog() async {
    _createNameController.clear();
    _createDescController.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lonca Kur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _createNameController,
              decoration: const InputDecoration(labelText: 'Lonca Adı'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _createDescController,
              decoration: const InputDecoration(labelText: 'Açıklama'),
              maxLines: 2,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _createNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              final ok = await ref.read(guildProvider.notifier).createGuild(
                    name: name,
                    description: _createDescController.text.trim(),
                  );
              if (!ok) {
                final err = ref.read(guildProvider).error;
                if (err != null) _showSnack(err);
              }
            },
            child: const Text('Kur'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemberActions({
    required GuildMemberData member,
    required GuildRole myRole,
    required String myPlayerId,
  }) async {
    if (member.playerId == myPlayerId) return;
    if (myRole == GuildRole.member) return;

    final bool canPromote = myRole == GuildRole.leader &&
        member.role == GuildRole.member;
    final bool canDemote = myRole == GuildRole.leader &&
        member.role == GuildRole.officer;
    final bool canKick = myRole == GuildRole.leader ||
        (myRole == GuildRole.officer && member.role == GuildRole.member);

    if (!canPromote && !canDemote && !canKick) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                '${_roleEmoji(member.role)} ${member.username} — ${_roleLabel(member.role)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            if (canPromote)
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded, color: Colors.green),
                title: const Text('Subay Yap'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'promote_guild_member',
                    successMsg: '${member.username} subay yapıldı.',
                  );
                },
              ),
            if (canDemote)
              ListTile(
                leading: const Icon(Icons.arrow_downward_rounded, color: Colors.orange),
                title: const Text('Üye Yap'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'demote_guild_member',
                    successMsg: '${member.username} üye yapıldı.',
                  );
                },
              ),
            if (canKick)
              ListTile(
                leading: const Icon(Icons.person_remove_rounded, color: Colors.red),
                title: const Text('Loncadan At'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _memberAction(
                    memberId: member.playerId,
                    rpcName: 'kick_guild_member',
                    successMsg: '${member.username} loncadan atıldı.',
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _memberAction({
    required String memberId,
    required String rpcName,
    required String successMsg,
  }) async {
    setState(() => _memberActionLoading = true);
    try {
      await SupabaseService.client.rpc(rpcName, params: <String, dynamic>{
        'p_member_id': memberId,
      });
      await ref.read(guildProvider.notifier).loadGuild();
      _showSnack(successMsg);
    } catch (e) {
      _showSnack('İşlem başarısız: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _memberActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guildState = ref.watch(guildProvider);
    final playerState = ref.watch(playerProvider);

    Future<void> onLogout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: onLogout),
      appBar: GameTopBar(title: 'Lonca', onLogout: onLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.guild),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: guildState.isLoading
            ? const Center(child: CircularProgressIndicator())
            : guildState.guild == null
                ? _NoGuildView(
                    searchController: _searchController,
                    searchResults: guildState.searchResults,
                    isLoading: guildState.isLoading,
                    error: guildState.error,
                    onSearch: _search,
                    onJoin: _joinGuild,
                    onCreate: _showCreateDialog,
                  )
                : _GuildView(
                    guild: guildState.guild!,
                    myPlayerId: playerState.profile?.id ?? '',
                    myRole: _myRole(guildState.guild!, playerState.profile?.id ?? ''),
                    memberActionLoading: _memberActionLoading,
                    onMemberTap: (member) => _showMemberActions(
                      member: member,
                      myRole: _myRole(guildState.guild!, playerState.profile?.id ?? ''),
                      myPlayerId: playerState.profile?.id ?? '',
                    ),
                    onLeave: _leaveGuild,
                    onGuildWar: () => context.go(AppRoutes.guildWar),
                    onMonument: () => context.go(AppRoutes.guildMonument),
                  ),
      ),
    );
  }

  GuildRole _myRole(GuildData guild, String playerId) {
    if (guild.members == null) {
      return guild.leaderId == playerId ? GuildRole.leader : GuildRole.member;
    }
    for (final m in guild.members!) {
      if (m.playerId == playerId) return m.role;
    }
    return GuildRole.member;
  }
}

// ---------------------------------------------------------------------------
// No-guild view
// ---------------------------------------------------------------------------
class _NoGuildView extends StatelessWidget {
  const _NoGuildView({
    required this.searchController,
    required this.searchResults,
    required this.isLoading,
    this.error,
    required this.onSearch,
    required this.onJoin,
    required this.onCreate,
  });

  final TextEditingController searchController;
  final List<GuildData> searchResults;
  final bool isLoading;
  final String? error;
  final VoidCallback onSearch;
  final Future<void> Function(String) onJoin;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Lonca',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Henüz bir loncaya üye değilsiniz.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          // Search bar
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Lonca ara...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onSearch,
                child: const Text('Ara'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search results
          if (searchResults.isNotEmpty) ...<Widget>[
            const Text(
              'Sonuçlar',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54),
            ),
            const SizedBox(height: 8),
            ...searchResults.map(
              (guild) => _GuildResultTile(guild: guild, onJoin: onJoin),
            ),
            const SizedBox(height: 16),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          // Create guild button
          OutlinedButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Lonca Kur'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4B6FFF)),
              foregroundColor: const Color(0xFF4B6FFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuildResultTile extends StatelessWidget {
  const _GuildResultTile({required this.guild, required this.onJoin});

  final GuildData guild;
  final Future<void> Function(String) onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  guild.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Lv.${guild.level} · ${guild.memberCount}/${guild.maxMembers} üye · ${guild.totalPower} güç',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => onJoin(guild.guildId),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4B6FFF),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Guild view (member of a guild)
// ---------------------------------------------------------------------------
class _GuildView extends StatelessWidget {
  const _GuildView({
    required this.guild,
    required this.myPlayerId,
    required this.myRole,
    required this.memberActionLoading,
    required this.onMemberTap,
    required this.onLeave,
    required this.onGuildWar,
    required this.onMonument,
  });

  final GuildData guild;
  final String myPlayerId;
  final GuildRole myRole;
  final bool memberActionLoading;
  final Future<void> Function(GuildMemberData) onMemberTap;
  final VoidCallback onLeave;
  final VoidCallback onGuildWar;
  final VoidCallback onMonument;

  @override
  Widget build(BuildContext context) {
    final List<GuildMemberData> sortedMembers = guild.members == null
        ? <GuildMemberData>[]
        : List<GuildMemberData>.from(guild.members!)
      ..sort((a, b) => _roleSortOrder(a.role).compareTo(_roleSortOrder(b.role)));

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Guild info header ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x334B6FFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.groups_rounded, color: Color(0xFF4B6FFF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        guild.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B6FFF).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Lv. ${guild.level}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF4B6FFF),
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: <Widget>[
                    _StatChip(
                        icon: Icons.people_rounded,
                        label: '${guild.memberCount}/${guild.maxMembers} Üye'),
                    _StatChip(
                        icon: Icons.bolt_rounded,
                        label: '${guild.totalPower} Güç'),
                    _StatChip(
                        icon: Icons.account_balance_outlined,
                        label: 'Anıt Lv.${guild.monumentLevel}'),
                    _StatChip(
                        icon: Icons.paid_rounded,
                        label: '${guild.monumentGoldPool} 🪙 Havuz'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Action buttons ──────────────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onGuildWar,
                  icon: const Icon(Icons.flag_rounded, size: 16),
                  label: const Text('Lonca Savaşı'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMonument,
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('Anıt'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onLeave,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                child: const Text('Çık'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Members list ────────────────────────────────────────────────
          Row(
            children: <Widget>[
              const Text(
                'Üyeler',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (memberActionLoading) ...<Widget>[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (sortedMembers.isEmpty)
            const Text(
              'Üye listesi yüklenemedi.',
              style: TextStyle(color: Colors.white38),
            )
          else
            ...sortedMembers.map(
              (member) => _MemberTile(
                member: member,
                isMe: member.playerId == myPlayerId,
                canAct: myRole != GuildRole.member &&
                    member.playerId != myPlayerId,
                onTap: () => onMemberTap(member),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canAct,
    required this.onTap,
  });

  final GuildMemberData member;
  final bool isMe;
  final bool canAct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool online = member.isOnline == true;
    return GestureDetector(
      onTap: canAct ? onTap : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF4B6FFF).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMe ? const Color(0x334B6FFF) : Colors.white12,
          ),
        ),
        child: Row(
          children: <Widget>[
            // Online dot
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green : Colors.white24,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        _roleEmoji(member.role),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        member.username,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: isMe
                              ? const Color(0xFF8BAEFF)
                              : Colors.white,
                        ),
                      ),
                      if (isMe)
                        const Text(
                          ' (Ben)',
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lv.${member.level} · ${_roleLabel(member.role)} · ${member.power} güç',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                ],
              ),
            ),
            if (canAct)
              const Icon(Icons.more_vert_rounded, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

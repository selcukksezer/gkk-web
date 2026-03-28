import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

const _kBonuses = [
  (5, 'XP Bonusu', '+%5 XP'),
  (10, 'Gold Bonusu', '+%3 Gold'),
  (15, 'Max Enerji', '+5 Max Enerji'),
  (20, 'Overdose Koruması', '-%10 Overdose Şansı'),
  (25, 'Tesis Hız', '-%5 Üretim Süresi'),
  (30, 'Zindan Şansı', '+10 Loot Şansı'),
  (35, 'Crafting Bonusu', '+%3 Craft Başarısı'),
  (40, 'PvP Kalkanı', '+%5 PvP Savunması'),
];

String _sizeLabel(int count) {
  if (count <= 10) return 'Küçük Lonca (0.35x)';
  if (count <= 20) return 'Orta Lonca (0.55x)';
  if (count <= 30) return 'Büyük Lonca (0.75x)';
  if (count <= 40) return 'Çok Büyük Lonca (0.90x)';
  return 'Maksimum Lonca (1.00x)';
}

class GuildMonumentScreen extends ConsumerStatefulWidget {
  const GuildMonumentScreen({super.key});

  @override
  ConsumerState<GuildMonumentScreen> createState() => _GuildMonumentScreenState();
}

class _GuildMonumentScreenState extends ConsumerState<GuildMonumentScreen> {
  Map<String, dynamic>? _guild;
  bool _loading = true;
  bool _upgrading = false;
  int _memberCount = 0;
  List<Map<String, dynamic>> _contributors = [];
  List<Map<String, dynamic>> _blueprints = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = ref.read(playerProvider).profile;
    final guildId = profile?.guildId;
    if (guildId == null) { setState(() => _loading = false); return; }

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.client.from('guilds').select().eq('id', guildId).single(),
        SupabaseService.client.from('users').select('id').eq('guild_id', guildId),
        SupabaseService.client.from('guild_contributions').select('user_id, contribution_score, gold_donated').eq('guild_id', guildId).order('contribution_score', ascending: false).limit(5),
        SupabaseService.client.from('guild_blueprints').select('blueprint_type, fragments, fragments_required, is_complete').eq('guild_id', guildId).order('blueprint_type'),
      ]);
      if (mounted) {
        setState(() {
          _guild = Map<String, dynamic>.from(results[0] as Map);
          _memberCount = (results[1] as List).length;
          _contributors = (results[2] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _blueprints = (results[3] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upgrade() async {
    final profile = ref.read(playerProvider).profile;
    final role = profile?.guildRole;
    if (role != 'leader' && role != 'commander') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetkiniz yok!')));
      return;
    }
    setState(() => _upgrading = true);
    try {
      final data = await SupabaseService.client.rpc('upgrade_monument', {'p_user_id': profile?.authId}) as Map;
      final result = Map<String, dynamic>.from(data);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anıt seviye ${result['new_level']} oldu')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error'] as String? ?? 'Yükseltme başarısız')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;
    final canUpgrade = profile?.guildRole == 'leader' || profile?.guildRole == 'commander';
    final monLevel = (_guild?['monument_level'] as num?)?.toInt() ?? 0;
    final structural = (_guild?['monument_structural'] as num?)?.toInt() ?? 0;
    final mystical = (_guild?['monument_mystical'] as num?)?.toInt() ?? 0;
    final critical = (_guild?['monument_critical'] as num?)?.toInt() ?? 0;
    final goldPool = (_guild?['monument_gold_pool'] as num?)?.toInt() ?? 0;

    void logout() async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '🏛️ Lonca Anıtı', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.guildMonument),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)])),
        child: profile?.guildId == null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Bir Loncaya Üye Değilsiniz', style: TextStyle(fontSize: 18, color: Colors.redAccent)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go(AppRoutes.guild), child: const Text('Lonca Bul')),
              ]))
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Lonca Anıtı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => context.go(AppRoutes.guildMonumentDonate),
                                  icon: const Icon(Icons.volunteer_activism, size: 16),
                                  label: const Text('Bağış Yap'),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                                ),
                                if (canUpgrade) ...[
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _upgrading ? null : _upgrade,
                                    child: _upgrading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Yükselt'),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Monument info card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 12)],
                                ),
                                child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 36))),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Seviye $monLevel Anıt', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    const Text('Lonca üyelerinin güçlerini birleştirerek yükselttiği kutsal yapı.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('$_memberCount / 50 Aktif Üye', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          Text(_sizeLabel(_memberCount), style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Resource grid
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 3,
                          children: [
                            _ResourceTile(label: 'Yapısal Kaynak', value: structural),
                            _ResourceTile(label: 'Mistik Kaynak', value: mystical),
                            _ResourceTile(label: 'Kritik Kaynak', value: critical),
                            _ResourceTile(label: 'Altın Havuzu', value: goldPool, isGold: true),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Monument bonuses
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.withValues(alpha: 0.3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('✨ Anıt Bonusları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple)),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                childAspectRatio: 2.5,
                                children: _kBonuses.map((b) => Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Lv ${b.$1}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                      Text(b.$2, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text(b.$3, style: const TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Contributors
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🏆 Katkı Liderleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFBBF24))),
                              const SizedBox(height: 12),
                              if (_contributors.isEmpty) const Text('Henüz katkı kaydı bulunmuyor.', style: TextStyle(color: Colors.white54, fontSize: 13))
                              else for (int i = 0; i < _contributors.length; i++)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                  child: Row(
                                    children: [
                                      Text('#${i + 1} ${(_contributors[i]['user_id'] as String? ?? '').substring(0, 8)}', style: const TextStyle(fontSize: 13)),
                                      const Spacer(),
                                      Text('${(_contributors[i]['contribution_score'] as num?)?.toInt() ?? 0}', style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Blueprints
                        if (_blueprints.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('🧩 Blueprint İlerlemesi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                const SizedBox(height: 12),
                                for (final bp in _blueprints)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                                    child: Row(
                                      children: [
                                        Expanded(child: Text(bp['blueprint_type'] as String? ?? '', style: const TextStyle(fontSize: 13))),
                                        Text(
                                          bp['is_complete'] == true ? 'Tamamlandı' : '${bp['fragments']}/${bp['fragments_required']}',
                                          style: TextStyle(color: bp['is_complete'] == true ? Colors.greenAccent : Colors.white54, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.label, required this.value, this.isGold = false});
  final String label;
  final int value;
  final bool isGold;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text('$value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isGold ? const Color(0xFFFBBF24) : Colors.white)),
      ],
    ),
  );
}

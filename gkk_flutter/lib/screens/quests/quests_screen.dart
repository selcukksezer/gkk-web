import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ── Filter types (mirrors QuestFilter in web) ───────────────────────────────
enum _QuestFilter { all, available, active, completed }

const _maxActiveQuests = 5;

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  List<QuestData> _quests = [];
  bool _loading = true;
  String? _error;
  _QuestFilter _activeFilter = _QuestFilter.all;
  bool _actionLoading = false;
  QuestData? _selectedQuest;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final level = ref.read(playerProvider).profile?.level ?? 1;
      final res = await SupabaseService.client.rpc('get_available_quests', params: {'p_player_level': level});
      final list = (res as List).map((e) => QuestData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) setState(() { _quests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _startQuest(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      final energy = ref.read(playerProvider).profile?.energy ?? 0;
      final activeCount = _quests.where((q) => q.status == QuestStatus.active).length;
      if (activeCount >= _maxActiveQuests) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktif görev slotları dolu!')));
        return;
      }
      if (energy < quest.energyCost) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yetersiz enerji!')));
        return;
      }
      await SupabaseService.client.rpc('start_quest', params: {'p_quest_id': quest.questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev başlatıldı!'), backgroundColor: Colors.green));
        setState(() => _selectedQuest = null);
        await _loadQuests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeQuest(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc('complete_quest', params: {'p_quest_id': quest.questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev tamamlandı! 🎉'), backgroundColor: Colors.green));
        await _loadQuests();
        ref.read(playerProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _claimReward(QuestData quest) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc('claim_quest_reward', params: {'p_quest_id': quest.questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ödül alındı: 🪙${quest.goldReward} + ✨${quest.xpReward} XP'), backgroundColor: Colors.green),
        );
        setState(() => _selectedQuest = null);
        _quests.removeWhere((q) => q.questId == quest.questId);
        setState(() {});
        ref.read(playerProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _abandonQuest(QuestData quest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2030),
        title: const Text('Görevi İptal Et'),
        content: const Text('Bu görevi iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc('abandon_quest', params: {'p_quest_id': quest.questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Görev iptal edildi.'), backgroundColor: Colors.green));
        setState(() => _selectedQuest = null);
        await _loadQuests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  List<QuestData> get _filteredQuests {
    switch (_activeFilter) {
      case _QuestFilter.all: return _quests;
      case _QuestFilter.available: return _quests.where((q) => q.status == QuestStatus.available).toList();
      case _QuestFilter.active: return _quests.where((q) => q.status == QuestStatus.active).toList();
      case _QuestFilter.completed: return _quests.where((q) => q.status == QuestStatus.completed).toList();
    }
  }

  void _showDetailModal(QuestData quest) {
    setState(() => _selectedQuest = quest);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2030),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              Text(quest.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                _badge(quest.difficulty.name, _diffColor(quest.difficulty)),
                const SizedBox(width: 6),
                _badge(quest.status.name, _statusColor(quest.status)),
              ]),
              const SizedBox(height: 10),
              Text(quest.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 14),
              const Text('📋 HEDEFLER', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ..._buildObjectives(quest).map((obj) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Text(obj.completed ? '☑️' : '☐', style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(obj.description, style: TextStyle(fontSize: 13, color: obj.completed ? Colors.greenAccent : Colors.white, decoration: obj.completed ? TextDecoration.lineThrough : null))),
                  if (obj.required > 1) Text('${obj.current}/${obj.required}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
              )),
              const SizedBox(height: 14),
              const Text('🎁 ÖDÜLLER', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  if (quest.goldReward > 0) _rewardRow('Altın', '🪙 ${quest.goldReward}', const Color(0xFFFBBF24)),
                  if (quest.xpReward > 0) _rewardRow('Deneyim', '✨ ${quest.xpReward} XP', const Color(0xFF818CF8)),
                  if (quest.gemReward > 0) _rewardRow('Gem', '💎 ${quest.gemReward}', const Color(0xFF8B5CF6)),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.bar_chart, size: 12, color: Colors.white38),
                Text(' Min Seviye: ${quest.requiredLevel}   ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const Icon(Icons.flash_on, size: 12, color: Colors.orange),
                Text(' Enerji: ${quest.energyCost}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))),
                const SizedBox(width: 8),
                if (quest.status == QuestStatus.available)
                  Expanded(child: ElevatedButton(
                    onPressed: _actionLoading ? null : () { Navigator.pop(ctx); _startQuest(quest); },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                    child: _actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Başlat'),
                  )),
                if (quest.status == QuestStatus.active)
                  Expanded(child: ElevatedButton(
                    onPressed: _actionLoading ? null : () { Navigator.pop(ctx); _abandonQuest(quest); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: _actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('İptal Et'),
                  )),
                if (quest.status == QuestStatus.completed)
                  Expanded(child: ElevatedButton(
                    onPressed: _actionLoading ? null : () { Navigator.pop(ctx); _claimReward(quest); },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: _actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('🎁 Ödülü Al'),
                  )),
              ]),
            ],
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _selectedQuest = null));
  }

  Color _diffColor(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy: return Colors.greenAccent;
      case QuestDifficulty.medium: return Colors.blueAccent;
      case QuestDifficulty.hard: return Colors.orange;
      case QuestDifficulty.elite: return Colors.redAccent;
      case QuestDifficulty.dungeon: return Colors.purpleAccent;
    }
  }

  Color _statusColor(QuestStatus s) {
    switch (s) {
      case QuestStatus.available: return Colors.white54;
      case QuestStatus.active: return Colors.amber;
      case QuestStatus.completed: return Colors.greenAccent;
      case QuestStatus.failed: return Colors.redAccent;
    }
  }

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.4))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
  );

  Widget _rewardRow(String label, String value, Color c) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      Text(value, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
    ]),
  );

  List<({String description, int current, int required, bool completed})> _buildObjectives(QuestData quest) {
    if (quest.status == QuestStatus.active) {
      return [(description: quest.description, current: quest.progress, required: quest.progressMax, completed: quest.progress >= quest.progressMax)];
    }
    if (quest.status == QuestStatus.completed) {
      return [(description: 'Görevi tamamla', current: 1, required: 1, completed: true)];
    }
    return [(description: 'Görevi kabul et', current: 0, required: 1, completed: false)];
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final playerLevel = ref.watch(playerProvider).profile?.level ?? 1;
    final playerEnergy = ref.watch(playerProvider).profile?.energy ?? 0;

    final activeCount = _quests.where((q) => q.status == QuestStatus.active).length;
    final completedCount = _quests.where((q) => q.status == QuestStatus.completed).length;
    final filteredQuests = _filteredQuests;

    const filterDefs = [
      (_QuestFilter.all, '🗒️', 'Tümü'),
      (_QuestFilter.available, '📋', 'Müsait'),
      (_QuestFilter.active, '⚡', 'Aktif'),
      (_QuestFilter.completed, '✅', 'Tamamlanan'),
    ];

    const emptyMessages = {
      _QuestFilter.all: 'Görev bulunamadı. Yenile veya bir sonraki seviyeye geç.',
      _QuestFilter.available: 'Seviyene uygun müsait görev bulunmuyor.',
      _QuestFilter.active: 'Henüz aktif görevin yok. Bir görev başlat!',
      _QuestFilter.completed: 'Henüz tamamladığın bir görev yok.',
    };

    return Scaffold(
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: '📜 Görevler', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.quests),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)]),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Aktif Görevler', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: activeCount >= _maxActiveQuests ? Colors.red.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$activeCount/$_maxActiveQuests', style: TextStyle(color: activeCount >= _maxActiveQuests ? Colors.redAccent : Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Stats row
              Row(children: [
                _statChip('${_quests.length}', 'Toplam', Colors.white),
                const SizedBox(width: 6),
                _statChip('$activeCount', 'Aktif', Colors.amber),
                const SizedBox(width: 6),
                _statChip('$completedCount', 'Tamamlanan', Colors.greenAccent),
              ]),
              const SizedBox(height: 10),
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filterDefs.map((f) {
                    final isActive = _activeFilter == f.$1;
                    final badgeCount = f.$1 == _QuestFilter.active ? activeCount : null;
                    return GestureDetector(
                      onTap: () => setState(() => _activeFilter = f.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isActive ? const Color(0xFF6366F1) : Colors.white24),
                        ),
                        child: Row(children: [
                          Text('${f.$2} ${f.$3}', style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (badgeCount != null && badgeCount > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                              child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Yüklenemedi: $_error', style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadQuests, child: const Text('🔄 Tekrar Dene')),
                      ]))
                    : filteredQuests.isEmpty
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text('📭', style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            Text(emptyMessages[_activeFilter] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
                          ]))
                        : RefreshIndicator(
                            onRefresh: _loadQuests,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              itemCount: filteredQuests.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index == filteredQuests.length) {
                                  return Center(
                                    child: TextButton.icon(
                                      onPressed: _loading ? null : _loadQuests,
                                      icon: const Icon(Icons.refresh, size: 14),
                                      label: const Text('🔄 Yenile', style: TextStyle(fontSize: 12)),
                                    ),
                                  );
                                }
                                final quest = filteredQuests[index];
                                return _QuestCard(
                                  quest: quest,
                                  playerLevel: playerLevel,
                                  playerEnergy: playerEnergy,
                                  activeCount: activeCount,
                                  maxActiveQuests: _maxActiveQuests,
                                  actionLoading: _actionLoading,
                                  onStart: () => _startQuest(quest),
                                  onComplete: () => _completeQuest(quest),
                                  onClaim: () => _claimReward(quest),
                                  onDetail: () => _showDetailModal(quest),
                                );
                              },
                            ),
                          ),
          ),
        ]),
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
      ]),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.playerLevel,
    required this.playerEnergy,
    required this.activeCount,
    required this.maxActiveQuests,
    required this.actionLoading,
    required this.onStart,
    required this.onComplete,
    required this.onClaim,
    required this.onDetail,
  });

  final QuestData quest;
  final int playerLevel;
  final int playerEnergy;
  final int activeCount;
  final int maxActiveQuests;
  final bool actionLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onClaim;
  final VoidCallback onDetail;

  Color get _diffColor {
    switch (quest.difficulty) {
      case QuestDifficulty.easy: return Colors.greenAccent;
      case QuestDifficulty.medium: return Colors.blueAccent;
      case QuestDifficulty.hard: return Colors.orange;
      case QuestDifficulty.elite: return Colors.redAccent;
      case QuestDifficulty.dungeon: return Colors.purpleAccent;
    }
  }

  String get _diffLabel {
    switch (quest.difficulty) {
      case QuestDifficulty.easy: return 'Kolay';
      case QuestDifficulty.medium: return 'Orta';
      case QuestDifficulty.hard: return 'Zor';
      case QuestDifficulty.elite: return 'Elite';
      case QuestDifficulty.dungeon: return 'Zindan';
    }
  }

  Color get _statusColor {
    switch (quest.status) {
      case QuestStatus.available: return Colors.white54;
      case QuestStatus.active: return Colors.amber;
      case QuestStatus.completed: return Colors.greenAccent;
      case QuestStatus.failed: return Colors.redAccent;
    }
  }

  String get _statusLabel {
    switch (quest.status) {
      case QuestStatus.available: return 'Mevcut';
      case QuestStatus.active: return 'Aktif';
      case QuestStatus.completed: return 'Tamamlandı';
      case QuestStatus.failed: return 'Başarısız';
    }
  }

  String? _expiresIn() {
    if (quest.expiresAt == null) return null;
    final dt = DateTime.tryParse(quest.expiresAt!);
    if (dt == null) return null;
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'Süresi doldu';
    if (diff.inDays > 0) return '${diff.inDays}g ${diff.inHours % 24}s kaldı';
    if (diff.inHours > 0) return '${diff.inHours}s ${diff.inMinutes % 60}dk kaldı';
    return '${diff.inMinutes}dk kaldı';
  }

  bool get _canStart =>
      quest.status == QuestStatus.available &&
      playerLevel >= quest.requiredLevel &&
      playerEnergy >= quest.energyCost &&
      activeCount < maxActiveQuests;

  @override
  Widget build(BuildContext context) {
    final progressPercent = quest.progressMax > 0
        ? (quest.progress / quest.progressMax).clamp(0.0, 1.0)
        : 0.0;
    final expiresLabel = _expiresIn();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(quest.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            _Badge(label: _diffLabel, color: _diffColor),
            const SizedBox(width: 6),
            _Badge(label: _statusLabel, color: _statusColor),
          ]),
          const SizedBox(height: 6),
          Text(quest.description, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              if (quest.goldReward > 0) _RewardChip(icon: Icons.paid_rounded, value: '${quest.goldReward}', color: Colors.amber),
              if (quest.xpReward > 0) _RewardChip(icon: Icons.star_rounded, value: '${quest.xpReward} XP', color: Colors.lightBlueAccent),
              if (quest.gemReward > 0) _RewardChip(icon: Icons.diamond_rounded, value: '${quest.gemReward}', color: Colors.purpleAccent),
              _RewardChip(icon: Icons.flash_on_rounded, value: '${quest.energyCost}', color: const Color(0xFF00D7D7)),
            ],
          ),
          if (playerLevel < quest.requiredLevel) ...<Widget>[
            const SizedBox(height: 8),
            Text('⚠️ Seviye ${quest.requiredLevel} gerekli (mevcut: $playerLevel)', style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
          if (quest.status == QuestStatus.active) ...<Widget>[
            const SizedBox(height: 10),
            Row(children: <Widget>[
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(
                value: progressPercent.toDouble(), minHeight: 6,
                backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ))),
              const SizedBox(width: 8),
              Text('${quest.progress}/${quest.progressMax}', style: const TextStyle(fontSize: 11, color: Colors.white60)),
            ]),
          ],
          if (expiresLabel != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(children: <Widget>[
              const Icon(Icons.timer_outlined, size: 12, color: Colors.orangeAccent),
              const SizedBox(width: 4),
              Text(expiresLabel, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
            ]),
          ],
          const SizedBox(height: 12),
          // Action row (Detay + primary action)
          Row(children: [
            OutlinedButton(
              onPressed: onDetail,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Detay', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Expanded(child: _mainActionButton()),
          ]),
        ],
      ),
    );
  }

  Widget _mainActionButton() {
    if (quest.status == QuestStatus.completed) {
      return FilledButton(
        onPressed: actionLoading ? null : onClaim,
        style: FilledButton.styleFrom(backgroundColor: Colors.green),
        child: actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('🎁 Ödülü Al'),
      );
    }
    if (quest.status == QuestStatus.failed) {
      return FilledButton(onPressed: null, style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.3)), child: const Text('✗ Başarısız'));
    }
    if (quest.status == QuestStatus.active && quest.progress >= quest.progressMax && quest.progressMax > 0) {
      return FilledButton(
        onPressed: actionLoading ? null : onComplete,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
        child: actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('✅ Tamamla'),
      );
    }
    if (quest.status == QuestStatus.active) {
      return FilledButton(onPressed: null, style: FilledButton.styleFrom(backgroundColor: Colors.amber.withValues(alpha: 0.3)), child: Text('⏳ Devam (${quest.progress}/${quest.progressMax})'));
    }
    if (quest.status == QuestStatus.available) {
      String label = 'Görevi Başlat';
      if (activeCount >= maxActiveQuests) label = '🔒 Slot Dolu';
      else if (playerLevel < quest.requiredLevel) label = 'Sev. ${quest.requiredLevel} Gerekli';
      else if (playerEnergy < quest.energyCost) label = 'Enerji Yetersiz';
      return FilledButton(
        onPressed: (!_canStart || actionLoading) ? null : onStart,
        child: actionLoading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(label),
      );
    }
    return FilledButton(onPressed: null, child: const Text('Mevcut Değil'));
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.value, required this.color});
  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

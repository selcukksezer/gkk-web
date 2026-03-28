import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/quest_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  List<QuestData> _quests = [];
  bool _loading = true;
  String? _error;
  QuestDifficulty? _selectedDifficulty;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadQuests();
  }

  Future<void> _loadQuests() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client.rpc('get_quests');
      final list = (res as List)
          .map((e) => QuestData.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() { _quests = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _startQuest(String questId) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client.rpc('start_quest', params: {'p_quest_id': questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Görev başlatıldı!'), backgroundColor: Colors.green),
        );
        await _loadQuests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeQuest(String questId) async {
    setState(() => _actionLoading = true);
    try {
      await SupabaseService.client
          .rpc('complete_quest', params: {'p_quest_id': questId});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Görev tamamlandı! 🎉'), backgroundColor: Colors.green),
        );
        await _loadQuests();
        ref.read(playerProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  List<QuestData> get _filteredQuests {
    if (_selectedDifficulty == null) return _quests;
    return _quests.where((q) => q.difficulty == _selectedDifficulty).toList();
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final playerLevel = ref.watch(playerProvider).profile?.level ?? 1;

    return Scaffold(
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: 'Görevler', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.quests),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _DiffTab(
                      label: 'Tümü',
                      selected: _selectedDifficulty == null,
                      color: Colors.white70,
                      onTap: () => setState(() => _selectedDifficulty = null),
                    ),
                    const SizedBox(width: 8),
                    _DiffTab(
                      label: 'Kolay',
                      selected: _selectedDifficulty == QuestDifficulty.easy,
                      color: Colors.greenAccent,
                      onTap: () => setState(() => _selectedDifficulty = QuestDifficulty.easy),
                    ),
                    const SizedBox(width: 8),
                    _DiffTab(
                      label: 'Orta',
                      selected: _selectedDifficulty == QuestDifficulty.medium,
                      color: Colors.blueAccent,
                      onTap: () =>
                          setState(() => _selectedDifficulty = QuestDifficulty.medium),
                    ),
                    const SizedBox(width: 8),
                    _DiffTab(
                      label: 'Zor',
                      selected: _selectedDifficulty == QuestDifficulty.hard,
                      color: Colors.orange,
                      onTap: () => setState(() => _selectedDifficulty = QuestDifficulty.hard),
                    ),
                    const SizedBox(width: 8),
                    _DiffTab(
                      label: 'Elite',
                      selected: _selectedDifficulty == QuestDifficulty.elite,
                      color: Colors.redAccent,
                      onTap: () =>
                          setState(() => _selectedDifficulty = QuestDifficulty.elite),
                    ),
                    const SizedBox(width: 8),
                    _DiffTab(
                      label: 'Zindan',
                      selected: _selectedDifficulty == QuestDifficulty.dungeon,
                      color: Colors.purpleAccent,
                      onTap: () =>
                          setState(() => _selectedDifficulty = QuestDifficulty.dungeon),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text('Yüklenemedi: $_error',
                              style: const TextStyle(color: Colors.redAccent)))
                      : _filteredQuests.isEmpty
                          ? const Center(
                              child: Text('Bu kategoride görev yok.',
                                  style: TextStyle(color: Colors.white54)))
                          : RefreshIndicator(
                              onRefresh: _loadQuests,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _filteredQuests.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final quest = _filteredQuests[index];
                                  return _QuestCard(
                                    quest: quest,
                                    playerLevel: playerLevel,
                                    actionLoading: _actionLoading,
                                    onStart: () => _startQuest(quest.questId),
                                    onComplete: () => _completeQuest(quest.questId),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _DiffTab extends StatelessWidget {
  const _DiffTab({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: selected
              ? color.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.playerLevel,
    required this.actionLoading,
    required this.onStart,
    required this.onComplete,
  });

  final QuestData quest;
  final int playerLevel;
  final bool actionLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  Color get _diffColor {
    switch (quest.difficulty) {
      case QuestDifficulty.easy:
        return Colors.greenAccent;
      case QuestDifficulty.medium:
        return Colors.blueAccent;
      case QuestDifficulty.hard:
        return Colors.orange;
      case QuestDifficulty.elite:
        return Colors.redAccent;
      case QuestDifficulty.dungeon:
        return Colors.purpleAccent;
    }
  }

  String get _diffLabel {
    switch (quest.difficulty) {
      case QuestDifficulty.easy:
        return 'Kolay';
      case QuestDifficulty.medium:
        return 'Orta';
      case QuestDifficulty.hard:
        return 'Zor';
      case QuestDifficulty.elite:
        return 'Elite';
      case QuestDifficulty.dungeon:
        return 'Zindan';
    }
  }

  Color get _statusColor {
    switch (quest.status) {
      case QuestStatus.available:
        return Colors.white54;
      case QuestStatus.active:
        return Colors.amber;
      case QuestStatus.completed:
        return Colors.greenAccent;
      case QuestStatus.failed:
        return Colors.redAccent;
    }
  }

  String get _statusLabel {
    switch (quest.status) {
      case QuestStatus.available:
        return 'Mevcut';
      case QuestStatus.active:
        return 'Aktif';
      case QuestStatus.completed:
        return 'Tamamlandı';
      case QuestStatus.failed:
        return 'Başarısız';
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

  Widget _actionButton() {
    if (quest.status == QuestStatus.completed) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.3)),
        child: const Text('✓ Tamamlandı'),
      );
    }
    if (quest.status == QuestStatus.failed) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.3)),
        child: const Text('✗ Başarısız'),
      );
    }
    if (playerLevel < quest.requiredLevel) {
      return FilledButton(
        onPressed: null,
        child: Text('Seviye ${quest.requiredLevel} Gerekli'),
      );
    }
    if (quest.status == QuestStatus.active && quest.progress >= quest.target) {
      return FilledButton(
        onPressed: actionLoading ? null : onComplete,
        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00C853)),
        child: actionLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Tamamla'),
      );
    }
    if (quest.status == QuestStatus.available) {
      return FilledButton(
        onPressed: actionLoading ? null : onStart,
        child: actionLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Başlat'),
      );
    }
    if (quest.status == QuestStatus.active) {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(
            backgroundColor: Colors.amber.withValues(alpha: 0.3)),
        child: Text('Devam Ediyor (${quest.progress}/${quest.target})'),
      );
    }
    return FilledButton(onPressed: null, child: const Text('Mevcut Değil'));
  }

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(quest.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              _Badge(label: _diffLabel, color: _diffColor),
              const SizedBox(width: 6),
              _Badge(label: _statusLabel, color: _statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Text(quest.description,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              if (quest.goldReward > 0)
                _RewardChip(
                    icon: Icons.paid_rounded,
                    value: '${quest.goldReward}',
                    color: Colors.amber),
              if (quest.xpReward > 0)
                _RewardChip(
                    icon: Icons.star_rounded,
                    value: '${quest.xpReward} XP',
                    color: Colors.lightBlueAccent),
              if (quest.gemReward > 0)
                _RewardChip(
                    icon: Icons.diamond_rounded,
                    value: '${quest.gemReward}',
                    color: Colors.purpleAccent),
              _RewardChip(
                  icon: Icons.flash_on_rounded,
                  value: '${quest.energyCost}',
                  color: const Color(0xFF00D7D7)),
            ],
          ),
          if (playerLevel < quest.requiredLevel) ...<Widget>[
            const SizedBox(height: 8),
            Text('Gerekli seviye: ${quest.requiredLevel}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
          if (quest.status == QuestStatus.active) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressPercent.toDouble(),
                      minHeight: 6,
                      backgroundColor: Colors.white12,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.amber),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${quest.progress}/${quest.progressMax}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
              ],
            ),
          ],
          if (expiresLabel != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                const Icon(Icons.timer_outlined, size: 12, color: Colors.orangeAccent),
                const SizedBox(width: 4),
                Text(expiresLabel,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: _actionButton()),
        ],
      ),
    );
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

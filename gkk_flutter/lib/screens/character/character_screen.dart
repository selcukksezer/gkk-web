import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../models/player_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

// ─── Class data ────────────────────────────────────────────────────────────
class _ClassData {
  const _ClassData({
    required this.name,
    required this.icon,
    required this.description,
    required this.classFeature,
    required this.bonuses,
  });
  final String name;
  final String icon;
  final String description;
  final String classFeature;
  final List<({String label, String value, Color color})> bonuses;
}

const _classData = {
  CharacterClass.warrior: _ClassData(
    name: '🗡️ Savaşçı',
    icon: '🗡️',
    description: 'Yeraltı dünyasının sert dövüşçüsü. Han\'ın en güçlü PvP oyuncusu.',
    classFeature: 'Kan Hırsı — PvP kazandıktan sonra 30 dk boyunca attack %10 artar (üst üste 3 kazanımda %20\'ye çıkar).',
    bonuses: [
      (label: 'PvP Hasar', value: '+20%', color: Colors.redAccent),
      (label: 'Boss Hasar', value: '+15%', color: Color(0xFFFBBF24)),
      (label: 'PvP Kritik Şansı', value: '+10%', color: Colors.orange),
      (label: 'Zindan Başarısı', value: '+5%', color: Colors.greenAccent),
      (label: 'Hastane Süresi', value: '-20%', color: Colors.white38),
    ],
  ),
  CharacterClass.alchemist: _ClassData(
    name: '⚗️ Simyacı',
    icon: '⚗️',
    description: 'İksirlerin ve formüllerin efendisi. Crafting ve üretim odaklı oyuncunun tercihi.',
    classFeature: 'Formül Ustası — Her gün 1 adet ücretsiz Minor Detox Drink üretme hakkı (craft malzemesi gerekmez).',
    bonuses: [
      (label: 'İksir Etkinliği', value: '+30%', color: Color(0xFF8B5CF6)),
      (label: 'Tolerans Artışı', value: '-25%', color: Colors.greenAccent),
      (label: 'Overdose Şansı', value: '-20%', color: Colors.greenAccent),
      (label: 'Crafting Başarısı', value: '+15%', color: Color(0xFFFBBF24)),
      (label: 'Han Üretim Süresi', value: '-20%', color: Colors.white38),
    ],
  ),
  CharacterClass.shadow: _ClassData(
    name: '🌑 Gölge',
    icon: '🌑',
    description: 'Şüphe altında faaliyet gösteren, gizliliği ve kaçınmayı benimseyen karakter.',
    classFeature: 'Gölgelik — Tesisler\'de şüphe artış hızı %30 düşük, rüşvet maliyeti %25 az.',
    bonuses: [
      (label: 'Tesis Şüphesi', value: '-30%', color: Colors.greenAccent),
      (label: 'Rüşvet Maliyeti', value: '-25%', color: Colors.greenAccent),
      (label: 'Hapişhaneden Kaçış', value: '+20%', color: Colors.orange),
      (label: 'Zindan Loot Şansı', value: '+40%', color: Color(0xFFFBBF24)),
      (label: 'PvP Kaçınma', value: '+15%', color: Colors.white38),
    ],
  ),
};

// ─── Skill definitions ──────────────────────────────────────────────────────
const _skills = [
  (key: 'combat',     label: 'Savaş',         icon: '⚔️', description: 'Yakın dövüş saldırı gücünü, kritik şansını ve savunma kabiliyetini artırır.',          color: Colors.redAccent),
  (key: 'stealth',    label: 'Gizlilik',       icon: '🥷', description: 'Kaçınma oranını ve gizli saldırı hasarını artırır. Şüphe birikimini yavaşlatır.',      color: Colors.white54),
  (key: 'magic',      label: 'Büyü',           icon: '🔮', description: 'Büyü gücünü ve enerji verimliliğini artırır. Özel büyülü becerileri açar.',            color: Color(0xFF8B5CF6)),
  (key: 'crafting',   label: 'Zanaatkarlık',   icon: '🔨', description: 'Daha iyi ekipman üretmeni sağlar. Başarı şansını ve kalite bonusunu artırır.',         color: Colors.orange),
  (key: 'trade',      label: 'Ticaret',         icon: '💰', description: 'Satış fiyatlarını artırır ve satın alım maliyetlerini düşürür.',                        color: Color(0xFFFBBF24)),
  (key: 'leadership', label: 'Liderlik',        icon: '👑', description: 'Grup bonuslarını artırır. Zindan ekibiyle senkronize XP kazanımını güçlendirir.',       color: Color(0xFFEF9B0F)),
];

const _defaultSkillLevels = {
  'combat': 3, 'stealth': 1, 'magic': 2, 'crafting': 0, 'trade': 1, 'leadership': 0,
};

// ─── Equipment slots ────────────────────────────────────────────────────────
const _equipSlots = [
  (key: 'weapon',    label: 'Silah',      icon: '⚔️'),
  (key: 'armor',     label: 'Zırh',       icon: '🛡️'),
  (key: 'helmet',    label: 'Kask',       icon: '⛑️'),
  (key: 'gloves',    label: 'Eldiven',    icon: '🧤'),
  (key: 'boots',     label: 'Ayakkabı',  icon: '👢'),
  (key: 'accessory', label: 'Aksesuar',  icon: '💍'),
];

// ─── Screen ─────────────────────────────────────────────────────────────────
class CharacterScreen extends ConsumerStatefulWidget {
  const CharacterScreen({super.key});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _claimingDetox = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(playerProvider.notifier).loadProfile();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Color _suspicionColor(int s) {
    if (s < 30) return Colors.greenAccent;
    if (s < 60) return Colors.orange;
    if (s < 80) return Colors.redAccent;
    return const Color(0xFFDC2626);
  }

  Future<void> _claimAlchemistDetox() async {
    setState(() => _claimingDetox = true);
    try {
      final res = await SupabaseService.client.rpc('claim_alchemist_detox') as Map;
      if (res['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Minor Detox başarıyla alındı!')));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ ${res['message'] ?? 'Bir hata oluştu.'}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ İşlem başarısız')));
    } finally {
      if (mounted) setState(() => _claimingDetox = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final profile = playerState.profile;

    void logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: '🧙 Karakter', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.character),
      body: switch (playerState.status) {
        PlayerStatus.initial || PlayerStatus.loading => const Center(child: CircularProgressIndicator()),
        PlayerStatus.error => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(playerState.errorMessage ?? 'Karakter bilgisi yüklenemedi.', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => ref.read(playerProvider.notifier).loadProfile(), child: const Text('Tekrar Dene')),
            ]),
          )),
        PlayerStatus.ready => _buildBody(profile, logout),
      },
    );
  }

  Widget _buildBody(PlayerProfile? profile, VoidCallback logout) {
    final level = profile?.level ?? 1;
    final xp = profile?.xp ?? 0;
    final nextXp = level * 1000; // approx
    final xpPct = nextXp > 0 ? (xp / nextXp).clamp(0.0, 1.0) : 0.0;

    final energy = profile?.energy ?? 0;
    final maxEnergy = profile?.maxEnergy ?? 100;
    final gold = profile?.gold ?? 0;
    final gems = profile?.gems ?? 0;
    final suspicion = profile?.globalSuspicionLevel ?? 0;
    final tolerance = profile?.tolerance ?? 0;
    final addictionLevel = profile?.addictionLevel ?? 0;
    final charClass = profile?.characterClass;

    // Combat formula (matches web)
    const baseHp = 100; const baseAtk = 5; const baseDef = 3; const baseSpeed = 10; const baseLuck = 5;
    final lvlHp = level * 10; final lvlAtk = level * 2; final lvlDef = level * 1;
    final finalHp = baseHp + lvlHp;
    final finalAtk = baseAtk + lvlAtk;
    final finalDef = baseDef + lvlDef;
    final finalSpeed = baseSpeed + (level * 0.3).floor();
    final finalLuck = baseLuck + (level * 0.5).floor();
    final critChance = (5 + (level * 0.4).floor()).clamp(0, 50);
    final critDamage = 150 + (level * 0.5).floor();
    final evasion = (level * 0.2).floor();

    // Buffs
    final isBloodlust = charClass == CharacterClass.warrior &&
        profile?.warriorBloodlustUntil != null &&
        DateTime.tryParse(profile!.warriorBloodlustUntil!)?.isAfter(DateTime.now()) == true;
    final lastPotion = profile?.lastPotionUsedAt;
    final isWithdrawal = addictionLevel >= 3 &&
        (lastPotion == null || DateTime.now().difference(DateTime.parse(lastPotion)).inHours >= 24);

    final displayName = profile?.displayName?.trim().isNotEmpty == true ? profile!.displayName! : (profile?.username ?? 'Oyuncu');

    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF090D14), Color(0xFF101722), Color(0xFF090D14)])),
      child: Column(
        children: [
          // Fixed top section (class card + buffs + XP + tabs)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                // Class card
                if (charClass != null) ...[
                  _buildClassCard(charClass, profile),
                  const SizedBox(height: 8),
                ],
                // Buffs
                if (isBloodlust || isWithdrawal) ...[
                  _buildBuffsCard(isBloodlust, isWithdrawal, addictionLevel),
                  const SizedBox(height: 8),
                ],
                // XP card
                _buildXpCard(displayName, level, xp, nextXp, xpPct),
                const SizedBox(height: 8),
                // Tab bar
                Container(
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(8)),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: const [Tab(text: '📊 Özellikler'), Tab(text: '🔧 Yetenekler'), Tab(text: '🏅 Başarımlar')],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // Stats tab
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildCombatTable(baseHp, 0, lvlHp, finalHp, baseAtk, 0, lvlAtk, finalAtk, baseDef, 0, lvlDef, finalDef, baseSpeed, finalSpeed, baseLuck, finalLuck, critChance, critDamage, evasion),
                    const SizedBox(height: 10),
                    if (charClass != null) ...[_buildClassBonuses(charClass), const SizedBox(height: 10)],
                    _buildEquipmentSlots(context),
                    const SizedBox(height: 10),
                    _buildResources(gold, gems, energy, maxEnergy, tolerance, suspicion),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.enhancement),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('⚡ Karakteri Güçlendir', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                // Skills tab
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text('Yetenekler seviye atlamayla ve görev ödülleriyle yükselir. Max seviye: 10.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    for (final skill in _skills) ...[_buildSkillCard(skill), const SizedBox(height: 8)],
                    const SizedBox(height: 8),
                    const Text('Yetenekleri geliştirmek için görevleri tamamla ve zindan kazan.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
                    const SizedBox(height: 16),
                  ],
                ),
                // Achievements tab
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _buildAchievementsTab(context),
                    const SizedBox(height: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(CharacterClass cls, PlayerProfile? profile) {
    final data = _classData[cls]!;
    final borderColor = cls == CharacterClass.warrior ? Colors.redAccent : cls == CharacterClass.alchemist ? const Color(0xFF8B5CF6) : Colors.white38;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(data.icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(data.description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Color(0xFF6366F1), width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⭐ Sınıf Özelliği', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(data.classFeature, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                if (cls == CharacterClass.alchemist) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _claimingDetox ? null : _claimAlchemistDetox,
                      icon: const Text('🧪', style: TextStyle(fontSize: 14)),
                      label: _claimingDetox ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Günlük Minor Detox Al', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuffsCard(bool isBloodlust, bool isWithdrawal, int addictionLvl) => Container(
    decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: const Border(left: BorderSide(color: Colors.orange, width: 4))),
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✨ Aktif Etkiler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        if (isBloodlust) Row(children: [const Text('🩸 Kan Hırsı: ', style: TextStyle(color: Colors.redAccent, fontSize: 12)), const Text('+10/20% ATK (Aktif)', style: TextStyle(color: Colors.white70, fontSize: 12))]),
        if (isWithdrawal) Row(children: [Text('🌀 Yoksunluk (Bağımlılık Lvl $addictionLvl): ', style: const TextStyle(color: Color(0xFFA78BFA), fontSize: 12)), const Expanded(child: Text('-20% HP, -15% ATK/DEF', style: TextStyle(color: Colors.white70, fontSize: 12)))]),
      ],
    ),
  );

  Widget _buildXpCard(String name, int level, int xp, int nextXp, double xpPct) => Container(
    decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        Row(
          children: [
            Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)])), alignment: Alignment.center, child: const Text('🧙', style: TextStyle(fontSize: 20))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('Seviye $level Kahraman', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Sıradaki Seviye', style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text('${(xpPct * 100).round()}%', style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
          ],
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: xpPct, backgroundColor: Colors.white12, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)), minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 4),
        Text('XP: $xp / $nextXp', style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    ),
  );

  Widget _buildCombatTable(int bHp, int eHp, int lHp, int fHp, int bAtk, int eAtk, int lAtk, int fAtk, int bDef, int eDef, int lDef, int fDef, int fSpeed, int fSpeedTotal, int bLuck, int fLuck, int critChance, int critDmg, int evasion) {
    final rows = [
      ('❤️ Sağlık', '$bHp', '+$eHp', '+$lHp', '$fHp', Colors.white),
      ('⚔️ Saldırı', '$bAtk', '+$eAtk', '+$lAtk', '$fAtk', Colors.white),
      ('🛡️ Savunma', '$bDef', '+$eDef', '+$lDef', '$fDef', Colors.white),
      ('💨 Hız', '$fSpeed', '+0', '+${fSpeedTotal - fSpeed}', '$fSpeedTotal', Colors.white),
      ('🍀 Şans', '$bLuck', '+0', '+${fLuck - bLuck}', '$fLuck', Colors.orange),
      ('🎯 Kritik Şans', '5%', '+0%', '+${critChance - 5}%', '$critChance%', Colors.orange),
      ('💥 Kritik Hasar', '150%', '+0%', '+${critDmg - 150}%', '$critDmg%', Colors.redAccent),
      ('🌀 Kaçınma', '0%', '+0%', '+$evasion%', '$evasion%', Colors.white),
    ];

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚔️ Savaş İstatistikleri', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _th('İstatistik')),
            _th('Taban'), const SizedBox(width: 8),
            _th('Ekipman'), const SizedBox(width: 8),
            _th('Seviye'), const SizedBox(width: 8),
            _th('Toplam'),
          ]),
          const Divider(color: Colors.white12, height: 8),
          for (final r in rows) Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12))),
              SizedBox(width: 44, child: Text(r.$2, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white38, fontSize: 12))),
              const SizedBox(width: 8),
              SizedBox(width: 50, child: Text(r.$3, textAlign: TextAlign.right, style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(r.$4, textAlign: TextAlign.right, style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12))),
              const SizedBox(width: 8),
              SizedBox(width: 44, child: Text(r.$5, textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: r.$6))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _th(String t) => Text(t, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600));

  Widget _buildClassBonuses(CharacterClass cls) {
    final data = _classData[cls]!;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🎭 Sınıf Bonusları — ${data.name}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: data.bonuses.map((b) => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: b.color, width: 3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(b.label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                Text(b.value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: b.color)),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentSlots(BuildContext context) => Container(
    decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('🛡️ Ekipman Slotları', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
          const Text('0/6 kuşanıldı', style: TextStyle(color: Colors.white38, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        for (final slot in _equipSlots) Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Text('${slot.icon} ${slot.label}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const Spacer(),
            const Text('— Boş —', style: TextStyle(color: Colors.white24, fontSize: 12, fontStyle: FontStyle.italic)),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: () => context.go(AppRoutes.inventory), child: const Text('Envantere Git →')),
        ),
      ],
    ),
  );

  Widget _buildResources(int gold, int gems, int energy, int maxEnergy, int tolerance, int suspicion) {
    final energyPct = maxEnergy > 0 ? (energy / maxEnergy).clamp(0.0, 1.0) : 0.0;
    final tolerancePct = (tolerance / 100).clamp(0.0, 1.0);
    final suspicionPct = (suspicion / 100).clamp(0.0, 1.0);

    Color suspColor(int s) {
      if (s < 30) return Colors.greenAccent;
      if (s < 60) return Colors.orange;
      return Colors.redAccent;
    }

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💰 Kaynaklar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('🪙 Altın', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('$gold', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFBBF24), fontSize: 13))]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('💎 Gem', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('$gems', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 13))]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('⚡ Enerji', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('$energy/$maxEnergy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: energyPct < 0.3 ? Colors.redAccent : Colors.orange))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: energyPct, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(energyPct < 0.3 ? Colors.redAccent : Colors.orange), minHeight: 6, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('🩺 Tolerans', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('$tolerance/100', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: tolerance < 40 ? Colors.greenAccent : tolerance < 70 ? Colors.orange : Colors.redAccent))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: tolerancePct, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(tolerance < 40 ? Colors.greenAccent : tolerance < 70 ? Colors.orange : Colors.redAccent), minHeight: 6, borderRadius: BorderRadius.circular(3)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('👁️ Şüphe Seviyesi', style: TextStyle(color: Colors.white54, fontSize: 12)), Text('$suspicion/100${suspicion >= 80 ? ' ⚠️' : ''}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: suspColor(suspicion)))]),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: suspicionPct, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(suspColor(suspicion)), minHeight: 6, borderRadius: BorderRadius.circular(3)),
          if (suspicion >= 60) ...[
            const SizedBox(height: 4),
            const Text('⚠️ Yüksek şüphe seviyesi! Yasal olmayan aktiviteleri azalt.', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillCard(({String key, String label, String icon, String description, Color color}) skill) {
    final lvl = _defaultSkillLevels[skill.key] ?? 0;

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: skill.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(skill.icon, style: const TextStyle(fontSize: 22))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(skill.label, style: TextStyle(fontWeight: FontWeight.bold, color: skill.color, fontSize: 14)),
                  Text('Sev $lvl/10', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 2),
                Text(skill.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: lvl / 10, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(skill.color), minHeight: 5, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(10, (i) => Container(
                    width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: i < lvl ? skill.color : Colors.white12),
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(BuildContext context) {
    const quickAchs = [
      (icon: '⚔️', label: 'İlk Zafer', desc: 'İlk zindanı tamamla', done: true),
      (icon: '📜', label: 'Görev Ustası', desc: '10 görev tamamla', done: false),
      (icon: '💰', label: 'Altın Biriktirici', desc: '10.000 altın biriktir', done: false),
      (icon: '🧙', label: 'Efsanevi Kahraman', desc: 'Seviye 25\'e ulaş', done: false),
      (icon: '🗺️', label: 'Kaşif', desc: 'Tüm bölgeleri ziyaret et', done: false),
      (icon: '🏰', label: 'Zindan Fatihi', desc: '5 farklı zindan tamamla', done: false),
    ];

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('🏅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Başarımlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Tamamladığın görevler, zindan zaferler ve özel etkinliklerden kazandığın başarımları görüntüle.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.achievements),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Başarımlar → 🏅'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔥 Öne Çıkan Başarımlar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              for (final a in quickAchs) Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: a.done ? Colors.green.withValues(alpha: 0.1) : Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: a.done ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
                ),
                child: Row(children: [
                  Text(a.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a.label}${a.done ? ' ✓' : ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.done ? Colors.greenAccent : Colors.white)),
                    Text(a.desc, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ])),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

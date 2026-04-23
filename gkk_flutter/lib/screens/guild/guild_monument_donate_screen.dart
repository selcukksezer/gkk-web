import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class GuildMonumentDonateScreen extends ConsumerStatefulWidget {
  const GuildMonumentDonateScreen({super.key});

  @override
  ConsumerState<GuildMonumentDonateScreen> createState() => _GuildMonumentDonateScreenState();
}

class _GuildMonumentDonateScreenState extends ConsumerState<GuildMonumentDonateScreen> {
  final _structuralCtrl = TextEditingController(text: '0');
  final _mysticalCtrl = TextEditingController(text: '0');
  final _criticalCtrl = TextEditingController(text: '0');
  final _goldCtrl = TextEditingController(text: '0');

  bool _loading = false;
  Map<String, int> _donatedToday = {'structural': 0, 'mystical': 0, 'critical': 0, 'gold': 0};

  // Daily limits
  static const int _maxStructural = 500;
  static const int _maxMystical = 200;
  static const int _maxCritical = 50;
  static const int _maxGold = 10000000;

  @override
  void initState() {
    super.initState();
    _loadDailyDonations();
  }

  @override
  void dispose() {
    _structuralCtrl.dispose();
    _mysticalCtrl.dispose();
    _criticalCtrl.dispose();
    _goldCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDailyDonations() async {
    final profile = ref.read(playerProvider).profile;
    final authId = profile?.authId;
    final guildId = profile?.guildId;
    if (authId == null || guildId == null) return;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final data = await SupabaseService.client
          .from('guild_daily_donations')
          .select('structural_today, mystical_today, critical_today, gold_today')
          .eq('user_id', authId)
          .eq('guild_id', guildId)
          .eq('donation_date', today)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _donatedToday = {
            'structural': (data['structural_today'] as num?)?.toInt() ?? 0,
            'mystical': (data['mystical_today'] as num?)?.toInt() ?? 0,
            'critical': (data['critical_today'] as num?)?.toInt() ?? 0,
            'gold': (data['gold_today'] as num?)?.toInt() ?? 0,
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _donate() async {
    final structural = int.tryParse(_structuralCtrl.text) ?? 0;
    final mystical = int.tryParse(_mysticalCtrl.text) ?? 0;
    final critical = int.tryParse(_criticalCtrl.text) ?? 0;
    final gold = int.tryParse(_goldCtrl.text) ?? 0;

    if (structural == 0 && mystical == 0 && critical == 0 && gold == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bağışlamak için bir miktar girin')));
      return;
    }

    setState(() => _loading = true);
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) throw Exception('Oturum yok');

      final data = await SupabaseService.client.rpc('donate_to_monument', params: {
        'p_user_id': user.id,
        'p_structural': structural,
        'p_mystical': mystical,
        'p_critical': critical,
        'p_gold': gold,
      }) as Map;

      final result = Map<String, dynamic>.from(data);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bağış başarılı! +${result['score_added']} Katkı Puanı')));
          context.go(AppRoutes.guildMonument);
        }
      } else {
        throw Exception(result['error'] ?? 'Bağış başarısız');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _resourceInput({
    required String label,
    required TextEditingController ctrl,
    required int todayUsed,
    required int dailyMax,
    required Color barColor,
  }) {
    final remaining = (dailyMax - todayUsed).clamp(0, dailyMax);
    final pct = dailyMax > 0 ? (todayUsed / dailyMax).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
            Text('Bugün: $todayUsed/$dailyMax', style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black26,
            border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixText: 'max $remaining',
            suffixStyle: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          onChanged: (v) {
            final n = int.tryParse(v) ?? 0;
            if (n > remaining) ctrl.text = '$remaining';
          },
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: pct, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation<Color>(barColor), minHeight: 3),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(playerProvider).profile;

    Future<void> logout() async { await ref.read(authProvider.notifier).logout(); ref.read(playerProvider.notifier).clear(); }

    if (profile?.guildId == null) {
      return Scaffold(
        appBar: GameTopBar(title: 'Anıta Bağış', onLogout: logout),
        body: const Center(child: Text('Lonca bulunamadı.', style: TextStyle(color: Colors.white54))),
      );
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: 'Anıta Bağış Yap', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.guildMonumentDonate),
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)])),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Anıta Bağış Yap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                TextButton(onPressed: () => context.go(AppRoutes.guildMonument), child: const Text('İptal')),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1A2030), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loncaya yapacağınız bağışlar anıtın seviyesini artırmanızı sağlar. Günlük limitlere dikkat edin.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 20),
                  _resourceInput(label: 'Yapısal Kaynak', ctrl: _structuralCtrl, todayUsed: _donatedToday['structural']!, dailyMax: _maxStructural, barColor: Colors.blue),
                  _resourceInput(label: 'Mistik Kaynak', ctrl: _mysticalCtrl, todayUsed: _donatedToday['mystical']!, dailyMax: _maxMystical, barColor: Colors.purple),
                  _resourceInput(label: 'Kritik Kaynak', ctrl: _criticalCtrl, todayUsed: _donatedToday['critical']!, dailyMax: _maxCritical, barColor: Colors.redAccent),
                  _resourceInput(label: 'Altın', ctrl: _goldCtrl, todayUsed: _donatedToday['gold']!, dailyMax: _maxGold, barColor: const Color(0xFFFBBF24)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _donate,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Bağışı Gönder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

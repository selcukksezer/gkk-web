import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

const Map<String, String> _mekanTypes = {
  'bar': 'Bar',
  'kahvehane': 'Kahvehane',
  'dovus_kulubu': 'Dövüş Kulübü',
  'luks_lounge': 'Lüks Lounge',
  'yeralti': 'Yeraltı',
};

class MekansScreen extends ConsumerStatefulWidget {
  const MekansScreen({super.key});

  @override
  ConsumerState<MekansScreen> createState() => _MekansScreenState();
}

class _MekansScreenState extends ConsumerState<MekansScreen> {
  List<Map<String, dynamic>> _mekans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.client.from('mekans').select('*').order('name');
      if (mounted) {
        setState(() {
          _mekans = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _doLogout() async {
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: GameDrawer(onLogout: _doLogout),
      appBar: GameTopBar(title: 'Mekanlar', onLogout: _doLogout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.mekans),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.myMekan),
                      icon: const Icon(Icons.store_rounded, size: 16),
                      label: const Text('Benim Mekanım'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.amber),
                        foregroundColor: Colors.amber,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(AppRoutes.mekanCreate),
                      icon: const Icon(Icons.add_business_rounded, size: 16),
                      label: const Text('Yeni Mekan Aç'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_error != null)
                _errorCard('Mekanlar yüklenemedi: $_error')
              else if (_mekans.isEmpty)
                _emptyCard('Henüz kayıtlı mekan yok.')
              else
                ..._mekans.map((mekan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MekanCard(
                        mekan: mekan,
                        onTap: () => context.go('/mekans/${mekan['id']}'),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.red.withValues(alpha: 0.08),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(child: Text(message, style: const TextStyle(color: Colors.white54))),
    );
  }
}

class _MekanCard extends StatelessWidget {
  const _MekanCard({required this.mekan, required this.onTap});
  final Map<String, dynamic> mekan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = mekan['name']?.toString() ?? '';
    final type = mekan['mekan_type']?.toString() ?? '';
    final typeLabel = _mekanTypes[type] ?? type;
    final level = _asInt(mekan['level']);
    final fame = _asInt(mekan['fame']);
    final isOpen = mekan['is_open'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isOpen
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.2),
                ),
                child: Text(
                  isOpen ? 'Açık' : 'Kapalı',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isOpen ? Colors.greenAccent : Colors.redAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(typeLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 12),
              Text('Seviye $level', style: const TextStyle(color: Colors.amber, fontSize: 12)),
              const SizedBox(width: 12),
              Text('Şöhret: $fame', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                foregroundColor: Colors.white70,
              ),
              child: const Text('Mekanı Ziyaret Et'),
            ),
          ),
        ],
      ),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}

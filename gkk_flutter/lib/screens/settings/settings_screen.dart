import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double _musicVolume = 0.7;
  double _sfxVolume = 0.8;
  bool _muteAll = false;
  bool _notifications = true;
  bool _autoBattle = false;

  late TextEditingController _nameController;
  bool _savingName = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProvider).profile;
    final name = profile?.displayName ?? profile?.username ?? '';
    _nameController = TextEditingController(text: name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.length < 3) {
      setState(() => _nameError = 'İsim en az 3 karakter olmalıdır.');
      return;
    }
    setState(() {
      _nameError = null;
      _savingName = true;
    });
    try {
      await SupabaseService.client.rpc('update_user_profile', params: {'p_display_name': name});
      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İsim başarıyla güncellendi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkmak istediğinize emin misiniz?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Çıkış Yap')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(authProvider.notifier).logout();
    ref.read(playerProvider.notifier).clear();
    if (mounted) context.go(AppRoutes.login);
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Sil', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Bu işlem geri alınamaz! Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Emin misiniz?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hesabı Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.client.rpc('delete_account');
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
      if (mounted) context.go(AppRoutes.login);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: GameDrawer(
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      appBar: GameTopBar(
        title: '⚙️ Ayarlar',
        onLogout: () async {
          await ref.read(authProvider.notifier).logout();
          ref.read(playerProvider.notifier).clear();
        },
      ),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.settings),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _sectionCard(
              title: '🔊 Ses Ayarları',
              children: <Widget>[
                _sliderTile(
                  label: '🎵 Müzik ${(_musicVolume * 100).round()}%',
                  value: _muteAll ? 0.0 : _musicVolume,
                  onChanged: _muteAll
                      ? null
                      : (v) => setState(() => _musicVolume = v),
                ),
                _sliderTile(
                  label: '🔔 Efektler ${(_sfxVolume * 100).round()}%',
                  value: _muteAll ? 0.0 : _sfxVolume,
                  onChanged: _muteAll
                      ? null
                      : (v) => setState(() => _sfxVolume = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🔇 Tüm Sesleri Kapat'),
                  value: _muteAll,
                  onChanged: (v) => setState(() => _muteAll = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: '📱 Bildirimler & Oyun',
              children: <Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bildirimler'),
                  value: _notifications,
                  onChanged: (v) => setState(() => _notifications = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('⚔️ Otomatik Savaş'),
                  subtitle: const Text(
                    'PvP ve zindan savaşlarını otomatik yönet',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  value: _autoBattle,
                  onChanged: (v) => setState(() => _autoBattle = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: '👤 Profil',
              children: <Widget>[
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Görünen İsim',
                    errorText: _nameError,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savingName ? null : _saveName,
                    child: _savingName
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kaydet'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionCard(
              title: '🚨 Hesap',
              children: <Widget>[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Çıkış Yap'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Hesabı Sil'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        color: Colors.black26,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5),
          ),
          const Divider(color: Colors.white12, height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _sliderTile({required String label, required double value, ValueChanged<double>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
        Slider(
          value: value,
          onChanged: onChanged,
          min: 0.0,
          max: 1.0,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _CharacterClassOption {
  const _CharacterClassOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
}

class CharacterSelectScreen extends ConsumerStatefulWidget {
  const CharacterSelectScreen({super.key});

  @override
  ConsumerState<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends ConsumerState<CharacterSelectScreen> {
  bool _loadingClasses = true;
  bool _submitting = false;
  String? _selectedClassId;
  String? _error;

  List<_CharacterClassOption> _classes = const <_CharacterClassOption>[
    _CharacterClassOption(
      id: 'warrior',
      name: 'Savaşçı',
      description: 'Yüksek savunma ve güç.',
      icon: Icons.shield_outlined,
    ),
    _CharacterClassOption(
      id: 'alchemist',
      name: 'Simyacı',
      description: 'İksir ve destek odaklı denge.',
      icon: Icons.auto_fix_high_outlined,
    ),
    _CharacterClassOption(
      id: 'shadow',
      name: 'Gölge',
      description: 'Yüksek hasar ve çeviklik.',
      icon: Icons.gps_fixed_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() {
      _loadingClasses = true;
      _error = null;
    });

    try {
      final dynamic response = await SupabaseService.client.rpc('get_character_classes');
      if (response is! Map<String, dynamic>) {
        return;
      }

      final bool success = response['success'] == true;
      final List<dynamic>? classes = response['classes'] as List<dynamic>?;
      if (!success || classes == null || classes.isEmpty) {
        return;
      }

      final Map<String, IconData> iconMap = <String, IconData>{
        'warrior': Icons.shield_outlined,
        'alchemist': Icons.auto_fix_high_outlined,
        'shadow': Icons.gps_fixed_outlined,
      };

      final List<_CharacterClassOption> parsed = classes
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> cls) {
        final String id = (cls['id'] as String?) ?? '';
        return _CharacterClassOption(
          id: id,
          name: (cls['name_tr'] as String?) ?? id,
          description: (cls['description_tr'] as String?) ?? '',
          icon: iconMap[id] ?? Icons.person_outline,
        );
      }).where((cls) => cls.id.isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        _classes = parsed;
      }
    } catch (_) {
      _error = 'Sınıf listesi yüklenemedi.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingClasses = false;
        });
      }
    }
  }

  Future<void> _selectClass() async {
    if (_selectedClassId == null || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final dynamic response = await SupabaseService.client.rpc(
        'select_character_class',
        params: <String, dynamic>{'p_class_id': _selectedClassId},
      );
      if (response is Map<String, dynamic> && response['success'] == false) {
        throw Exception((response['error'] as String?) ?? 'Sınıf seçimi başarısız.');
      }

      await ref.read(playerProvider.notifier).loadProfile();
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Sınıf seçimi başarısız oldu. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karakter Seç'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF10131D), Color(0xFF171E2C), Color(0xFF10131D)],
          ),
        ),
        child: Center(
          child: Container(
            width: 420,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
              color: Colors.black26,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Karakter Seç', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Oyuna başlamak için bir sınıf seç.', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 16),
                if (_loadingClasses)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                else ...<Widget>[
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: _classes.map((cls) {
                      final bool selected = _selectedClassId == cls.id;
                      return GestureDetector(
                        onTap: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _selectedClassId = cls.id;
                                });
                              },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: selected ? const Color(0xFF5296FF) : Colors.white24),
                            color: selected ? const Color(0x335296FF) : Colors.white10,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(cls.icon, size: 32, color: Colors.white70),
                              const SizedBox(height: 6),
                              Text(cls.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                cls.description,
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selected ? 'Seçildi' : 'Seç',
                                style: TextStyle(
                                  color: selected ? const Color(0xFF8AB6FF) : const Color(0xFF5296FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  if (_error != null) ...<Widget>[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _selectedClassId == null || _submitting ? null : _selectClass,
                      child: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Maceraya Başla'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

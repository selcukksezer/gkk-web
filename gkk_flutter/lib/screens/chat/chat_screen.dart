import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../components/layout/game_chrome.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_provider.dart';
import '../../routing/app_router.dart';

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.channel,
    required this.message,
    required this.userId,
    required this.username,
    required this.createdAt,
  });

  final String id;
  final String channel;
  final String message;
  final String userId;
  final String username;
  final String createdAt;

  factory _ChatMessage.fromJson(Map<String, dynamic> j) => _ChatMessage(
        id: j['id']?.toString() ?? '',
        channel: j['channel'] as String? ?? '',
        message: j['message'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        username: j['username'] as String? ?? 'Anonim',
        createdAt: j['created_at'] as String? ?? '',
      );
}

const List<String> _channels = <String>['Genel', 'Lonca', 'Dünya'];

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<_ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String _currentChannel = 'Genel';
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.client
          .from('chat_messages')
          .select('*')
          .eq('channel', _currentChannel)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _messages = (data as List)
              .map((e) =>
                  _ChatMessage.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final currentUserId =
        SupabaseService.client.auth.currentUser?.id ?? '';
    if (currentUserId.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await SupabaseService.client.from('chat_messages').insert({
        'channel': _currentChannel,
        'message': text,
        'user_id': currentUserId,
      });
      if (mounted) {
        _controller.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mesaj gönderilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = SupabaseService.client
        .channel('chat')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final row = payload.newRecord;
            if (row['channel'] != _currentChannel) return;
            final msg =
                _ChatMessage.fromJson(Map<String, dynamic>.from(row));
            if (mounted) {
              setState(() => _messages.insert(0, msg));
            }
          },
        )
        .subscribe();
  }

  void _switchChannel(String channel) {
    if (channel == _currentChannel) return;
    setState(() => _currentChannel = channel);
    _loadMessages();
    _subscribeRealtime();
  }

  String _timeAgo(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Az önce';
      if (diff.inHours < 1) return '${diff.inMinutes}dk önce';
      if (diff.inDays < 1) return '${diff.inHours}sa önce';
      return '${diff.inDays}g önce';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    void logout() async {
      await ref.read(authProvider.notifier).logout();
      ref.read(playerProvider.notifier).clear();
    }

    return Scaffold(
      drawer: GameDrawer(onLogout: logout),
      appBar: GameTopBar(title: 'Sohbet', onLogout: logout),
      bottomNavigationBar: const GameBottomBar(currentRoute: AppRoutes.chat),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Sohbet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    for (final String ch in _channels)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _switchChannel(ch),
                          child: Chip(
                            label: Text(ch),
                            backgroundColor: ch == _currentChannel
                                ? const Color(0xFFFBBF24).withValues(alpha: 0.2)
                                : Colors.white10,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: ch == _currentChannel
                                  ? const Color(0xFFFBBF24)
                                  : Colors.white70,
                            ),
                            side: BorderSide(
                              color: ch == _currentChannel
                                  ? const Color(0xFFFBBF24)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white10,
                    ),
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                            ? const Center(
                                child: Text('Mesaj yok.',
                                    style: TextStyle(color: Colors.white38)),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.all(10),
                                itemCount: _messages.length,
                                itemBuilder: (context, i) {
                                  final msg = _messages[i];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Row(
                                                children: <Widget>[
                                                  Text(
                                                    msg.username,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFFFBBF24),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _timeAgo(msg.createdAt),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.white38,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                msg.message,
                                                style: const TextStyle(
                                                    fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !_isSending,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Mesaj yaz...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white10,
                          border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(10))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

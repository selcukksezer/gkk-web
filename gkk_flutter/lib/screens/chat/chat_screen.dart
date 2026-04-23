import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';
import '../../providers/player_provider.dart';

// ============================================================================
// DESIGN SYSTEM - Colors, Spacing, Shadows, Gradients
// ============================================================================
class _ChatDesignSystem {
  // Channel brand colors
  static const Color colorGlobalAccent = Color(0xFF38BDF8); // Sky blue
  static const Color colorGuildAccent = Color(0xFFF97316); // Guild orange
  static const Color colorTradeAccent = Color(0xFFFCCC15); // Trade amber
  static const Color colorDmAccent = Color(0xFFA855F7); // DM purple

  // Semantic colors
  static const Color colorSuccess = Color(0xFF10B981);
  static const Color colorError = Color(0xFFF87171);
  static const Color colorWarning = Color(0xFFFB923C);
  static const Color colorInfo = Color(0xFF0EA5E9);

  // Background & surfaces (dark theme)
  static const Color colorBgSecondary = Color(0xFF090D15);
  // unused: static const Color colorBgOverlay = Color(0xFF1E293B);

  // Text colors
  static const Color colorTextPrimary = Colors.white;
  static const Color colorTextSecondary = Color(0xFFE2E8F0);
  static const Color colorTextTertiary = Color(0xFF94A3B8);

  // Spacing scale
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  // unused: static const double spaceXl = 24;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusRound = 999;

  // Animation
  static const Duration durationBase = Duration(milliseconds: 200);
  // unused: static const Duration durationSlow = Duration(milliseconds: 300);
  static const Curve curveEaseInOut = Curves.easeInOutCubic;

  // Shadows
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  // Gradients
  static const LinearGradient gradientBgPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0141B26), Color(0xFFF0090D15)],
  );

  static const LinearGradient gradientGlobal = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1F38BDF8), Color(0x0638BDF8)],
  );

  static const LinearGradient gradientGuild = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FF97316), Color(0x06F97316)],
  );

  static const LinearGradient gradientTrade = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FFCCC15), Color(0x06FCCC15)],
  );

  static const LinearGradient gradientDm = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0x1FA855F7), Color(0x06A855F7)],
  );
}

enum _ChatChannel { global, guild, trade, dm }

extension _ChatChannelX on _ChatChannel {
  String get key {
    switch (this) {
      case _ChatChannel.global:
        return 'global';
      case _ChatChannel.guild:
        return 'guild';
      case _ChatChannel.trade:
        return 'trade';
      case _ChatChannel.dm:
        return 'dm';
    }
  }

  String get label {
    switch (this) {
      case _ChatChannel.global:
        return 'Genel';
      case _ChatChannel.guild:
        return 'Lonca';
      case _ChatChannel.trade:
        return 'Pazar';
      case _ChatChannel.dm:
        return 'Özel';
    }
  }

  Color get accentColor {
    switch (this) {
      case _ChatChannel.global:
        return _ChatDesignSystem.colorGlobalAccent;
      case _ChatChannel.guild:
        return _ChatDesignSystem.colorGuildAccent;
      case _ChatChannel.trade:
        return _ChatDesignSystem.colorTradeAccent;
      case _ChatChannel.dm:
        return _ChatDesignSystem.colorDmAccent;
    }
  }

  LinearGradient get gradient {
    switch (this) {
      case _ChatChannel.global:
        return _ChatDesignSystem.gradientGlobal;
      case _ChatChannel.guild:
        return _ChatDesignSystem.gradientGuild;
      case _ChatChannel.trade:
        return _ChatDesignSystem.gradientTrade;
      case _ChatChannel.dm:
        return _ChatDesignSystem.gradientDm;
    }
  }

  static _ChatChannel fromKey(String value) {
    switch (value) {
      case 'guild':
        return _ChatChannel.guild;
      case 'trade':
        return _ChatChannel.trade;
      case 'dm':
        return _ChatChannel.dm;
      case 'global':
      default:
        return _ChatChannel.global;
    }
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class _ChatMessage {
  const _ChatMessage({
    required this.id,
    required this.channel,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isSystem,
    this.recipientUserId,
    this.guildId,
    this.deletedAt,
  });

  final String id;
  final _ChatChannel channel;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isSystem;
  final String? recipientUserId;
  final String? guildId;
  final String? deletedAt;

  factory _ChatMessage.fromJson(Map<String, dynamic> json) {
    final String rawChannel = (json['channel']?.toString() ?? 'global').toLowerCase();
    final String ts = json['created_at']?.toString() ?? json['timestamp']?.toString() ?? DateTime.now().toIso8601String();

    return _ChatMessage(
      id: json['id']?.toString() ?? '',
      channel: _ChatChannelX.fromKey(rawChannel),
      senderId: (json['sender_user_id'] ?? json['sender_id'] ?? json['user_id'] ?? json['author_id'])?.toString() ?? '',
      senderName: (json['sender_name'] ?? json['sender_username'] ?? json['username'] ?? json['user_name'])?.toString() ?? 'Oyuncu',
      content: (json['content'] ?? json['message'])?.toString() ?? '',
      timestamp: DateTime.tryParse(ts)?.toLocal() ?? DateTime.now(),
      isSystem: (json['is_system'] as bool?) ?? false,
      recipientUserId: json['recipient_user_id']?.toString(),
      guildId: json['guild_id']?.toString(),
      deletedAt: json['deleted_at']?.toString(),
    );
  }
}

class _ChatUserSummary {
  const _ChatUserSummary({
    required this.id,
    required this.username,
    this.displayName,
  });

  final String id;
  final String username;
  final String? displayName;

  factory _ChatUserSummary.fromJson(Map<String, dynamic> json) => _ChatUserSummary(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? 'oyuncu',
        displayName: json['display_name']?.toString(),
      );
}

class _ChatDmConversation {
  const _ChatDmConversation({
    required this.peerUserId,
    required this.peerUsername,
    required this.lastMessageContent,
    required this.lastMessageAt,
    required this.unreadCount,
    this.peerDisplayName,
  });

  final String peerUserId;
  final String peerUsername;
  final String? peerDisplayName;
  final String lastMessageContent;
  final DateTime lastMessageAt;
  final int unreadCount;

  factory _ChatDmConversation.fromJson(Map<String, dynamic> json) {
    final DateTime ts = DateTime.tryParse(json['last_message_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    return _ChatDmConversation(
      peerUserId: json['peer_user_id']?.toString() ?? '',
      peerUsername: json['peer_username']?.toString() ?? 'oyuncu',
      peerDisplayName: json['peer_display_name']?.toString(),
      lastMessageContent: json['last_message_content']?.toString() ?? '',
      lastMessageAt: ts,
      unreadCount: ((json['unread_count'] as num?) ?? 0).toInt().clamp(0, 99),
    );
  }
}

class _BlockedChatUser {
  const _BlockedChatUser({
    required this.id,
    required this.username,
    this.displayName,
  });

  final String id;
  final String username;
  final String? displayName;

  factory _BlockedChatUser.fromJson(Map<String, dynamic> json) => _BlockedChatUser(
        id: (json['blocked_user_id'] ?? json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: json['display_name']?.toString(),
      );
}

class _ChatFilter {
  const _ChatFilter({
    required this.id,
    required this.term,
    required this.replacement,
    required this.scope,
  });

  final String id;
  final String term;
  final String replacement;
  final String scope;

  factory _ChatFilter.fromJson(Map<String, dynamic> json) => _ChatFilter(
        id: json['id']?.toString() ?? '',
        term: json['term']?.toString() ?? '',
        replacement: json['replacement']?.toString() ?? '***',
        scope: json['scope']?.toString() ?? 'channel',
      );
}

class _ChatBan {
  const _ChatBan({
    required this.reason,
    required this.expiresAt,
    required this.scope,
    this.channel,
  });

  final String reason;
  final DateTime expiresAt;
  final String scope;
  final String? channel;

  factory _ChatBan.fromJson(Map<String, dynamic> json) => _ChatBan(
        reason: json['reason']?.toString() ?? 'Sohbet erişimi kısıtlandı.',
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        scope: json['scope']?.toString() ?? 'channel',
        channel: json['channel']?.toString(),
      );
}

class _ChatPermissions {
  const _ChatPermissions({
    required this.canDelete,
    required this.canBan,
    required this.canManageFilters,
    required this.canManageModerators,
  });

  final bool canDelete;
  final bool canBan;
  final bool canManageFilters;
  final bool canManageModerators;

  factory _ChatPermissions.fromJson(Map<String, dynamic>? json) => _ChatPermissions(
        canDelete: (json?['can_delete'] as bool?) ?? false,
        canBan: (json?['can_ban'] as bool?) ?? false,
        canManageFilters: (json?['can_manage_filters'] as bool?) ?? false,
        canManageModerators: (json?['can_manage_moderators'] as bool?) ?? false,
      );
}

class _ChatModerationState {
  const _ChatModerationState({
    required this.channel,
    required this.filters,
    required this.activeBans,
    required this.permissions,
  });

  final _ChatChannel channel;
  final List<_ChatFilter> filters;
  final List<_ChatBan> activeBans;
  final _ChatPermissions permissions;

  factory _ChatModerationState.empty(_ChatChannel channel) => _ChatModerationState(
        channel: channel,
        filters: const <_ChatFilter>[],
        activeBans: const <_ChatBan>[],
        permissions: _ChatPermissions.fromJson(null),
      );

  factory _ChatModerationState.fromJson(_ChatChannel channel, Map<String, dynamic>? json) {
    final List<dynamic> rawFilters = (json?['filters'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> rawBans = (json?['active_bans'] as List<dynamic>?) ?? <dynamic>[];

    return _ChatModerationState(
      channel: channel,
      filters: rawFilters.whereType<Map>().map((Map f) => _ChatFilter.fromJson(Map<String, dynamic>.from(f))).toList(growable: false),
      activeBans: rawBans.whereType<Map>().map((Map b) => _ChatBan.fromJson(Map<String, dynamic>.from(b))).toList(growable: false),
      permissions: _ChatPermissions.fromJson((json?['permissions'] as Map?)?.cast<String, dynamic>()),
    );
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.asPanel = false});

  final bool asPanel;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const int _maxMessageLength = 200;
  static const Duration _rateLimitDuration = Duration(seconds: 2);

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _dmSearchController = TextEditingController();
  final TextEditingController _filterTermController = TextEditingController();
  final TextEditingController _filterReplacementController = TextEditingController(text: '***');
  final ScrollController _scrollController = ScrollController();

  final Map<_ChatChannel, List<_ChatMessage>> _messages = <_ChatChannel, List<_ChatMessage>>{
    _ChatChannel.global: <_ChatMessage>[],
    _ChatChannel.guild: <_ChatMessage>[],
    _ChatChannel.trade: <_ChatMessage>[],
    _ChatChannel.dm: <_ChatMessage>[],
  };

  final Set<String> _mutedPlayers = <String>{};
  final Set<String> _blockedPlayers = <String>{};
  final Map<String, _BlockedChatUser> _blockedUsers = <String, _BlockedChatUser>{};

  _ChatChannel _activeChannel = _ChatChannel.global;
  _ChatModerationState _moderationState = _ChatModerationState.empty(_ChatChannel.global);
  List<_ChatDmConversation> _dmConversations = <_ChatDmConversation>[];
  List<_ChatUserSummary> _dmSearchResults = <_ChatUserSummary>[];

  _ChatUserSummary? _activeDmPeer;

  bool _isLoading = false;
  bool _isSending = false;
  bool _isDmLoading = false;
  bool _isDmSearchLoading = false;
  bool _isModerationLoading = false;

  int _guildUnreadCount = 0;
  DateTime _lastMessageSentAt = DateTime.fromMillisecondsSinceEpoch(0);

  RealtimeChannel? _realtimeChannel;

  String get _currentAuthUserId => SupabaseService.client.auth.currentUser?.id ?? '';

  String get _currentGameUserId => ref.read(playerProvider).profile?.id ?? '';

  String get _currentUserId =>
      _currentGameUserId.isNotEmpty ? _currentGameUserId : _currentAuthUserId;

  bool _isOwnSender(String senderId) {
    if (senderId.isEmpty) return false;
    return senderId == _currentGameUserId || senderId == _currentAuthUserId;
  }

  int get _dmUnreadCount => _dmConversations.fold<int>(0, (int total, _ChatDmConversation item) => total + item.unreadCount);

  List<_ChatMessage> get _currentMessages => _messages[_activeChannel] ?? const <_ChatMessage>[];

  _ChatBan? get _activeBan {
    for (final _ChatBan ban in _moderationState.activeBans) {
      if (ban.scope == 'global') return ban;
      if (ban.channel == _activeChannel.key) return ban;
      if (_activeChannel == _ChatChannel.guild && ban.scope == 'guild') return ban;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
    unawaited(_syncBlockedUsers());
    _subscribeRealtime();
    unawaited(_loadForChannel(_activeChannel));
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _dmSearchController.dispose();
    _filterTermController.dispose();
    _filterReplacementController.dispose();
    _scrollController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<dynamic> _rpc(String fn, {Map<String, dynamic>? params}) async {
    return SupabaseService.client.rpc(fn, params: params);
  }

  Future<void> _loadForChannel(_ChatChannel channel) async {
    setState(() {
      _isLoading = true;
      _activeChannel = channel;
      if (channel == _ChatChannel.guild) {
        _guildUnreadCount = 0;
      }
      if (channel != _ChatChannel.dm) {
        _activeDmPeer = null;
      }
    });

    try {
      if (channel == _ChatChannel.dm) {
        await Future.wait(<Future<void>>[
          _loadModerationState(channel),
          _loadDmConversations(),
        ]);
      } else {
        await Future.wait(<Future<void>>[
          _loadHistory(channel),
          _loadModerationState(channel),
        ]);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadHistory(_ChatChannel channel, {int limit = 50}) async {
    final dynamic res = await _rpc('get_chat_history', params: <String, dynamic>{'p_channel': channel.key, 'p_limit': limit});

    final List<_ChatMessage> parsed = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => _ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => !_blockedPlayers.contains(m.senderId) && !_mutedPlayers.contains(m.senderId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (!mounted) return;
    setState(() {
      _messages[channel] = parsed;
    });
    _scheduleScrollToBottom(immediate: true);
  }

  Future<void> _loadDmConversations() async {
    setState(() => _isDmLoading = true);
    try {
      final dynamic res = await _rpc('get_dm_conversations');
      final List<_ChatDmConversation> items = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => _ChatDmConversation.fromJson(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      if (!mounted) return;
      setState(() => _dmConversations = items);
    } finally {
      if (mounted) setState(() => _isDmLoading = false);
    }
  }

  Future<void> _loadDmMessages(String peerUserId, {int limit = 50}) async {
    final dynamic res = await _rpc('get_dm_messages', params: <String, dynamic>{'p_peer_user_id': peerUserId, 'p_limit': limit});

    final List<_ChatMessage> parsed = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => _ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => !_blockedPlayers.contains(m.senderId) && !_mutedPlayers.contains(m.senderId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (!mounted) return;
    setState(() {
      _messages[_ChatChannel.dm] = parsed;
    });
    _scheduleScrollToBottom(immediate: true);
  }

  Future<void> _markDmRead(String peerUserId) async {
    await _rpc('mark_dm_conversation_read', params: <String, dynamic>{'p_peer_user_id': peerUserId});
  }

  Future<void> _searchDmUsers(String query, {int limit = 8}) async {
    final String trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() => _dmSearchResults = <_ChatUserSummary>[]);
      return;
    }

    setState(() => _isDmSearchLoading = true);
    try {
      final dynamic res = await _rpc('search_chat_users', params: <String, dynamic>{'p_query': trimmed, 'p_limit': limit});

      final List<_ChatUserSummary> users = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => _ChatUserSummary.fromJson(Map<String, dynamic>.from(m)))
          .toList(growable: false);

      if (!mounted) return;
      setState(() => _dmSearchResults = users);
    } finally {
      if (mounted) setState(() => _isDmSearchLoading = false);
    }
  }

  Future<void> _loadModerationState(_ChatChannel channel) async {
    setState(() => _isModerationLoading = true);
    try {
      final dynamic res = await _rpc('get_chat_moderation_state', params: <String, dynamic>{'p_channel': channel.key});

      if (!mounted) return;
      setState(() {
        _moderationState = _ChatModerationState.fromJson(channel, (res as Map?)?.cast<String, dynamic>());
      });
    } catch (_) {
      if (mounted) {
        setState(() => _moderationState = _ChatModerationState.empty(channel));
      }
    } finally {
      if (mounted) setState(() => _isModerationLoading = false);
    }
  }

  Future<void> _syncBlockedUsers() async {
    try {
      final dynamic res = await _rpc('get_blocked_chat_users');
      final List<_BlockedChatUser> users = ((res as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((Map m) => _BlockedChatUser.fromJson(Map<String, dynamic>.from(m)))
          .where((u) => u.id.isNotEmpty)
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _blockedUsers
          ..clear()
          ..addEntries(users.map((u) => MapEntry<String, _BlockedChatUser>(u.id, u)));
        _blockedPlayers
          ..clear()
          ..addAll(_blockedUsers.keys);
        _mutedPlayers
          ..clear()
          ..addAll(_blockedUsers.keys);
      });
    } catch (_) {
      // Backward compatible: old DB may not have this RPC yet.
    }
  }

  Future<void> _unmutePlayer(
    String playerId, {
    String? playerName,
    bool showToast = true,
  }) async {
    if (playerId.isEmpty) return;

    bool serverUnblocked = false;

    try {
      final dynamic res = await _rpc('unblock_chat_user', params: <String, dynamic>{'p_blocked_user_id': playerId});
      final Map<String, dynamic>? data = res is Map ? Map<String, dynamic>.from(res) : null;
      serverUnblocked = data?['success'] == true;
    } catch (_) {
      serverUnblocked = false;
    }

    if (!mounted) return;

    setState(() {
      _mutedPlayers.remove(playerId);
      _blockedPlayers.remove(playerId);
      _blockedUsers.remove(playerId);
    });

    if (serverUnblocked) {
      await _loadForChannel(_activeChannel);
      await _loadDmConversations();
      if (showToast) {
        _showSnack('@${playerName ?? 'oyuncu'} için susturma kaldırıldı.');
      }
    } else if (showToast) {
      _showSnack('Yerel susturma kaldırıldı. Kalıcı kaldırma için migration gerekli olabilir.');
    }
  }

  Future<void> _openBlockedUsersSheet() async {
    await _syncBlockedUsers();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0D1117),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        final List<_BlockedChatUser> users = _blockedUsers.values.toList(growable: false);
        if (users.isEmpty) {
          return const SafeArea(
            child: SizedBox(
              height: 180,
              child: Center(
                child: Text('Susturulan kullanıcı yok.', style: TextStyle(color: Colors.white70)),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Susturulanlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (BuildContext context, int index) {
                      final _BlockedChatUser u = users[index];
                      final String label = u.displayName?.isNotEmpty == true ? u.displayName! : u.username;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text('@$label', style: const TextStyle(color: Colors.white)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                unawaited(_unmutePlayer(u.id, playerName: label));
                              },
                              child: const Text('Susturmayı Kaldır'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDmConversation(_ChatUserSummary peer) async {
    setState(() {
      _activeChannel = _ChatChannel.dm;
      _activeDmPeer = peer;
      _isLoading = true;
    });

    try {
      await _loadDmMessages(peer.id);
      await _markDmRead(peer.id);
      await _loadDmConversations();
      await _loadModerationState(_ChatChannel.dm);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _leaveDmConversation() {
    setState(() {
      _activeDmPeer = null;
      _messages[_ChatChannel.dm] = <_ChatMessage>[];
    });
  }

  Future<void> _sendMessage() async {
    final String raw = _messageController.text;
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) return;

    final Duration diff = DateTime.now().difference(_lastMessageSentAt);
    if (diff < _rateLimitDuration) {
      _showSnack('Çok hızlı yazıyorsunuz!');
      return;
    }

    if (trimmed.length > _maxMessageLength) {
      _showSnack('Mesaj çok uzun (max $_maxMessageLength karakter)');
      return;
    }

    _ChatChannel targetChannel = _activeChannel;
    String targetContent = trimmed;
    String? recipientId = _activeDmPeer?.id;

    if (_activeChannel != _ChatChannel.dm) {
      final RegExpMatch? mention = RegExp(r'^@([a-zA-Z0-9_.-]+)\s+([\s\S]+)$').firstMatch(trimmed);
      if (mention != null) {
        final String username = mention.group(1) ?? '';
        final String rest = (mention.group(2) ?? '').trim();
        if (rest.isEmpty) {
          _showSnack('Özel mesaj içeriği boş olamaz.');
          return;
        }
        final _ChatUserSummary? peer = await _resolveDmUserByUsername(username);
        if (peer == null) {
          _showSnack('Bu kullanıcı adına ait oyuncu bulunamadı.');
          return;
        }
        targetChannel = _ChatChannel.dm;
        recipientId = peer.id;
        targetContent = rest;
      }
    }

    if (targetChannel == _ChatChannel.dm && (recipientId == null || recipientId.isEmpty)) {
      _showSnack('Özel mesaj için önce bir oyuncu seçin.');
      return;
    }

    if (recipientId != null && (_mutedPlayers.contains(recipientId) || _blockedPlayers.contains(recipientId))) {
      _showSnack('Bu oyuncu susturuldu/engellendiği için özel mesaj gönderemezsiniz.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final dynamic result = await _rpc('send_chat_message', params: <String, dynamic>{
        'p_channel': targetChannel.key,
        'p_content': targetContent,
        'p_recipient_user_id': recipientId,
      });
      final Map<String, dynamic>? response = result is Map ? Map<String, dynamic>.from(result) : null;

      if (response?['success'] == true) {
        _lastMessageSentAt = DateTime.now();
        final dynamic messagePayload = response?['message'];
        if (messagePayload is Map) {
          final _ChatMessage serverMessage = _ChatMessage.fromJson(Map<String, dynamic>.from(messagePayload));
          _appendIfAbsent(targetChannel, serverMessage);
        } else {
          _appendLocalMessage(
            channel: targetChannel,
            content: targetContent,
            recipientUserId: recipientId,
          );
        }
        _messageController.clear();
        _scheduleScrollToBottom(immediate: true);

        // Server state ile hizalamak için hızlı bir yenileme yap.
        if (targetChannel == _ChatChannel.dm && recipientId != null && recipientId.isNotEmpty) {
          await _loadDmMessages(recipientId);
          await _loadDmConversations();
        } else {
          await _loadHistory(targetChannel);
        }

        if (targetChannel == _ChatChannel.dm) {
          await _loadDmConversations();
        }
      } else {
        _showSnack(response?['error']?.toString() ?? 'Mesaj gönderilemedi');
      }
    } catch (e) {
      _showSnack('Mesaj gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<_ChatUserSummary?> _resolveDmUserByUsername(String username) async {
    final String normalized = username.replaceFirst('@', '').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final dynamic res = await _rpc('search_chat_users', params: <String, dynamic>{'p_query': normalized, 'p_limit': 10});

    final List<_ChatUserSummary> users = ((res as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map m) => _ChatUserSummary.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);

    for (final _ChatUserSummary u in users) {
      if (u.username.toLowerCase() == normalized) {
        return u;
      }
    }
    return null;
  }

  Future<void> _mutePlayer(String playerId, {String? playerName}) async {
    if (playerId.isEmpty) {
      _showSnack('Geçersiz kullanıcı.');
      return;
    }

    setState(() {
      _mutedPlayers.add(playerId);
      _blockedPlayers.add(playerId);
      _blockedUsers[playerId] = _BlockedChatUser(
        id: playerId,
        username: playerName ?? 'oyuncu',
        displayName: playerName,
      );
      _messages.updateAll(
        (_, List<_ChatMessage> list) =>
            list.where((m) => m.senderId != playerId).toList(growable: false),
      );
      if (_activeDmPeer?.id == playerId) {
        _activeDmPeer = null;
      }
    });

    try {
      await _rpc('block_chat_user', params: <String, dynamic>{'p_blocked_user_id': playerId});
      if (mounted) {
        final String label = playerName ?? _blockedUsers[playerId]?.username ?? 'oyuncu';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('@$label susturuldu.'),
            action: SnackBarAction(
              label: 'Geri Al',
              onPressed: () {
                unawaited(_unmutePlayer(playerId, playerName: label, showToast: false));
              },
            ),
          ),
        );
      }
      await _loadForChannel(_activeChannel);
    } catch (_) {
      _showSnack('Oyuncu yerel olarak susturuldu, sunucu engeli uygulanamadı.');
    }
  }

  Future<void> _reportMessage(String messageId, String reason) async {
    try {
      final dynamic res = await _rpc('report_chat_message', params: <String, dynamic>{'p_message_id': messageId, 'p_reason': reason, 'p_details': null});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Rapor gönderildi.');
      } else {
        _showSnack(response?['error']?.toString() ?? 'Rapor gönderilemedi.');
      }
    } catch (e) {
      _showSnack('Rapor gönderilemedi: $e');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final dynamic res = await _rpc('delete_chat_message', params: <String, dynamic>{'p_message_id': messageId, 'p_reason': 'moderator_delete'});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        setState(() {
          _messages[_activeChannel] = (_messages[_activeChannel] ?? <_ChatMessage>[]).where((m) => m.id != messageId).toList(growable: false);
        });
        _showSnack('Mesaj silindi.');
      } else {
        _showSnack(response?['error']?.toString() ?? 'Mesaj silinemedi.');
      }
    } catch (e) {
      _showSnack('Mesaj silinemedi: $e');
    }
  }

  Future<void> _banPlayer(_ChatMessage msg) async {
    final TextEditingController minuteCtrl = TextEditingController(text: '30');
    final TextEditingController reasonCtrl = TextEditingController(text: 'kural ihlali');

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${msg.senderName} için ban'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: minuteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Süre (dakika)'),
              ),
              const SizedBox(height: _ChatDesignSystem.spaceMd),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(labelText: 'Sebep'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Uygula')),
          ],
        );
      },
    );

    if (ok != true) return;

    final int duration = int.tryParse(minuteCtrl.text.trim()) ?? 0;
    final String reason = reasonCtrl.text.trim().isEmpty ? 'kural ihlali' : reasonCtrl.text.trim();
    if (duration <= 0) {
      _showSnack('Geçerli bir süre girin.');
      return;
    }

    try {
      final dynamic res = await _rpc('ban_chat_user', params: <String, dynamic>{
        'p_target_user_id': msg.senderId,
        'p_channel': _activeChannel.key,
        'p_duration_minutes': duration,
        'p_reason': reason,
      });
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Oyuncu geçici olarak sohbetten uzaklaştırıldı.');
      } else {
        _showSnack(response?['error']?.toString() ?? 'Ban uygulanamadı.');
      }
    } catch (e) {
      _showSnack('Ban uygulanamadı: $e');
    }
  }

  Future<void> _assignModerator(_ChatMessage msg) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Moderator Atama'),
        content: Text('${msg.senderName} bu kanal için moderator yapılsın mı?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Onayla')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final dynamic res = await _rpc('assign_chat_moderator', params: <String, dynamic>{'p_target_user_id': msg.senderId, 'p_channel': _activeChannel.key});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Moderator atandı.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Moderator atanamadı.');
      }
    } catch (e) {
      _showSnack('Moderator atanamadı: $e');
    }
  }

  Future<void> _createFilter() async {
    final String term = _filterTermController.text.trim();
    final String replacement = _filterReplacementController.text.trim().isEmpty ? '***' : _filterReplacementController.text.trim();

    if (term.isEmpty) {
      _showSnack('Filtre kelimesi boş olamaz.');
      return;
    }

    try {
      final dynamic res = await _rpc('create_chat_filter', params: <String, dynamic>{
        'p_term': term,
        'p_replacement': replacement,
        'p_channel': _activeChannel.key,
      });
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _filterTermController.clear();
        _filterReplacementController.text = '***';
        _showSnack('Filtre eklendi.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Filtre eklenemedi.');
      }
    } catch (e) {
      _showSnack('Filtre eklenemedi: $e');
    }
  }

  Future<void> _deleteFilter(String filterId) async {
    try {
      final dynamic res = await _rpc('delete_chat_filter', params: <String, dynamic>{'p_filter_id': filterId});
      final Map<String, dynamic>? response = res is Map ? Map<String, dynamic>.from(res) : null;
      if (response?['success'] == true) {
        _showSnack('Filtre silindi.');
        await _loadModerationState(_activeChannel);
      } else {
        _showSnack(response?['error']?.toString() ?? 'Filtre silinemedi.');
      }
    } catch (e) {
      _showSnack('Filtre silinemedi: $e');
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = SupabaseService.client
        .channel('chat_messages_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (PostgresChangePayload payload) {
            final Map<String, dynamic> newRow = Map<String, dynamic>.from(payload.newRecord);
            final Map<String, dynamic> oldRow = Map<String, dynamic>.from(payload.oldRecord);

            if (newRow.isNotEmpty && newRow['deleted_at'] != null) {
              _removeMessage(newRow['id']?.toString() ?? '', newRow['channel']?.toString());
              return;
            }

            if (newRow.isEmpty && oldRow.isNotEmpty) {
              _removeMessage(oldRow['id']?.toString() ?? '', oldRow['channel']?.toString());
              return;
            }

            if (newRow.isEmpty) return;

            final _ChatMessage msg = _ChatMessage.fromJson(newRow);
            if (_blockedPlayers.contains(msg.senderId) || _mutedPlayers.contains(msg.senderId)) {
              return;
            }

            if (msg.channel == _ChatChannel.dm) {
              _handleIncomingDm(msg);
              return;
            }

            if (msg.channel == _ChatChannel.guild && msg.senderId != _currentUserId && _activeChannel != _ChatChannel.guild) {
              setState(() => _guildUnreadCount = (_guildUnreadCount + 1).clamp(0, 99));
            }

            _appendIfAbsent(msg.channel, msg);
          },
        )
        .subscribe();
  }

  void _handleIncomingDm(_ChatMessage msg) {
    if (_currentUserId.isEmpty) return;

    final bool isOwn = _isOwnSender(msg.senderId);
    final String peerId = isOwn ? (msg.recipientUserId ?? '') : msg.senderId;
    if (peerId.isEmpty) return;

    final bool isActiveThread = _activeChannel == _ChatChannel.dm && _activeDmPeer?.id == peerId;
    if (isActiveThread) {
      _appendIfAbsent(_ChatChannel.dm, msg);
      if (!isOwn) {
        unawaited(_markDmRead(peerId));
      }
    }

    unawaited(_loadDmConversations());
  }

  void _appendIfAbsent(_ChatChannel channel, _ChatMessage message) {
    if (!mounted) return;
    setState(() {
      final List<_ChatMessage> prev = List<_ChatMessage>.from(_messages[channel] ?? const <_ChatMessage>[]);
      if (prev.any((m) => m.id == message.id)) return;
      prev.add(message);
      prev.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (prev.length > 100) {
        prev.removeRange(0, prev.length - 100);
      }
      _messages[channel] = prev;
    });
    _scheduleScrollToBottom();
  }

  void _appendLocalMessage({
    required _ChatChannel channel,
    required String content,
    required String? recipientUserId,
  }) {
    final String senderId = _currentUserId;
    final String nowIso = DateTime.now().toIso8601String();
    final Map<String, dynamic> payload = <String, dynamic>{
      'id': 'local_${DateTime.now().microsecondsSinceEpoch}',
      'channel': channel.key,
      'sender_user_id': senderId,
      'sender_name': 'Sen',
      'content': content,
      'created_at': nowIso,
      'is_system': false,
      'recipient_user_id': recipientUserId,
    };
    _appendIfAbsent(channel, _ChatMessage.fromJson(payload));
  }

  void _handleComposerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _scheduleScrollToBottom({bool immediate = false, int retries = 4}) {
    void attempt(int remaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (!_scrollController.hasClients) {
          if (remaining > 0) {
            Future<void>.delayed(const Duration(milliseconds: 80), () {
              attempt(remaining - 1);
            });
          }
          return;
        }

        final double target = _scrollController.position.maxScrollExtent;

        if (immediate) {
          _scrollController.jumpTo(target);
        } else {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }

        if (remaining > 0 && (_scrollController.position.maxScrollExtent - _scrollController.offset) > 8) {
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            attempt(remaining - 1);
          });
        }
      });
    }

    attempt(retries);
  }

  void _removeMessage(String id, String? channelKey) {
    if (!mounted || id.isEmpty) return;
    final _ChatChannel channel = _ChatChannelX.fromKey(channelKey ?? 'global');
    setState(() {
      _messages[channel] = (_messages[channel] ?? const <_ChatMessage>[]).where((m) => m.id != id).toList(growable: false);
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(DateTime dt) {
    final String hh = dt.hour.toString().padLeft(2, '0');
    final String mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final bool showDmPanel = _activeChannel == _ChatChannel.dm;
    final bool showComposer = _activeChannel != _ChatChannel.dm || _activeDmPeer != null;

    final Widget body = Column(
      children: <Widget>[
        if (widget.asPanel)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        _buildChannelBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
            child: Column(
              children: <Widget>[
                _buildBanBanner(),
                _buildModerationPanel(),
                Expanded(
                  child: showDmPanel ? _buildDmPanel() : _buildMessageList(),
                ),
              ],
            ),
          ),
        ),
        if (showComposer) _buildComposer(),
      ],
    );

    if (widget.asPanel) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbet'),
        centerTitle: true,
      ),
      body: body,
    );
  }

  Widget _buildChannelBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd),
      child: Row(
        children: <Widget>[
          ..._ChatChannel.values.map((c) {
          final bool active = c == _activeChannel;
          final int badge = c == _ChatChannel.guild ? _guildUnreadCount : c == _ChatChannel.dm ? _dmUnreadCount : 0;

          return Padding(
            padding: const EdgeInsets.only(right: _ChatDesignSystem.spaceMd),
            child: GestureDetector(
              onTap: () => _loadForChannel(c),
              child: AnimatedContainer(
                duration: _ChatDesignSystem.durationBase,
                curve: _ChatDesignSystem.curveEaseInOut,
                padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceLg, vertical: _ChatDesignSystem.spaceSm),
                decoration: BoxDecoration(
                  gradient: active ? c.gradient : LinearGradient(colors: [Colors.transparent, Colors.transparent]),
                  border: Border.all(
                    color: active ? c.accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
                    width: active ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
                  boxShadow: active ? _ChatDesignSystem.shadowMd : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(c.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? c.accentColor : _ChatDesignSystem.colorTextTertiary)),
                    if (badge > 0) ...<Widget>[
                      const SizedBox(width: _ChatDesignSystem.spaceSm),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceSm, vertical: _ChatDesignSystem.spaceXs),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [c.accentColor.withValues(alpha: 0.3), c.accentColor.withValues(alpha: 0.15)]),
                          border: Border.all(color: c.accentColor.withValues(alpha: 0.4), width: 0.8),
                          borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusRound),
                        ),
                        child: Text(badge > 99 ? '99+' : '$badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.accentColor)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
          GestureDetector(
            onTap: _openBlockedUsersSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceSm),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.volume_off_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('Susturulanlar${_blockedUsers.isEmpty ? '' : ' (${_blockedUsers.length})'}',
                      style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanBanner() {
    final _ChatBan? ban = _activeBan;
    if (ban == null) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: _ChatDesignSystem.durationBase,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_ChatDesignSystem.colorError.withValues(alpha: 0.15), _ChatDesignSystem.colorError.withValues(alpha: 0.05)]),
        border: Border.all(color: _ChatDesignSystem.colorError.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
        boxShadow: [BoxShadow(color: _ChatDesignSystem.colorError.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(color: _ChatDesignSystem.colorError.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd)),
                  child: Icon(Icons.block_rounded, size: 14, color: _ChatDesignSystem.colorError),
                ),
                const SizedBox(width: _ChatDesignSystem.spaceSm),
                const Text('Sohbet Erişimi Kısıtlandı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorError)),
              ],
            ),
            const SizedBox(height: _ChatDesignSystem.spaceSm),
            Padding(
              padding: const EdgeInsets.only(left: _ChatDesignSystem.spaceLg + _ChatDesignSystem.spaceSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(ban.reason, style: const TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextSecondary)),
                  const SizedBox(height: _ChatDesignSystem.spaceXs),
                  Text('Bitiş: ${ban.expiresAt.toString().split('.')[0]}', style: TextStyle(fontSize: 10, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModerationPanel() {
    if (!_moderationState.permissions.canManageFilters) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceMd),
      decoration: BoxDecoration(
        gradient: _ChatDesignSystem.gradientBgPanel,
        border: Border.all(color: _ChatDesignSystem.colorWarning.withValues(alpha: 0.25), width: 1),
        borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
        boxShadow: _ChatDesignSystem.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_ChatDesignSystem.colorWarning.withValues(alpha: 0.08), _ChatDesignSystem.colorWarning.withValues(alpha: 0.02)]),
              border: Border(bottom: BorderSide(color: _ChatDesignSystem.colorWarning.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.filter_list_rounded, size: 18, color: _ChatDesignSystem.colorWarning),
                const SizedBox(width: _ChatDesignSystem.spaceSm),
                const Text('Filtre Yönetimi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary)),
                const Spacer(),
                if (_isModerationLoading)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_ChatDesignSystem.colorWarning.withValues(alpha: 0.6))),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(flex: 2, child: _buildFilterTextField(controller: _filterTermController, label: 'Filtrelenecek kelime')),
                    const SizedBox(width: _ChatDesignSystem.spaceMd),
                    Expanded(flex: 1, child: _buildFilterTextField(controller: _filterReplacementController, label: 'Yerine konan')),
                    const SizedBox(width: _ChatDesignSystem.spaceMd),
                    _buildModButton(onPressed: _createFilter, label: 'Ekle'),
                  ],
                ),
                if (_moderationState.filters.isNotEmpty) ...<Widget>[
                  const SizedBox(height: _ChatDesignSystem.spaceMd),
                  Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  const SizedBox(height: _ChatDesignSystem.spaceMd),
                  Text('Aktif Filtreler (${_moderationState.filters.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorTextTertiary)),
                  const SizedBox(height: _ChatDesignSystem.spaceSm),
                  ...List.generate(_moderationState.filters.length, (int idx) {
                    final _ChatFilter f = _moderationState.filters[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceSm),
                      child: Container(
                        padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), border: Border.all(color: Colors.white.withValues(alpha: 0.06)), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd)),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text('"${f.term}" → "${f.replacement}"', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(f.scope, style: const TextStyle(fontSize: 10, color: _ChatDesignSystem.colorTextTertiary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: _ChatDesignSystem.spaceSm),
                            GestureDetector(
                              onTap: () => _deleteFilter(f.id),
                              child: Container(
                                padding: const EdgeInsets.all(_ChatDesignSystem.spaceXs),
                                decoration: BoxDecoration(color: _ChatDesignSystem.colorError.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusSm)),
                                child: Icon(Icons.close_rounded, size: 16, color: _ChatDesignSystem.colorError),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTextField({required TextEditingController controller, required String label}) {
    return Container(
      decoration: BoxDecoration(
        color: _ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceSm),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildModButton({required VoidCallback onPressed, required String label}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceLg, vertical: _ChatDesignSystem.spaceSm),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_ChatDesignSystem.colorSuccess.withValues(alpha: 0.3), _ChatDesignSystem.colorSuccess.withValues(alpha: 0.15)]),
          border: Border.all(color: _ChatDesignSystem.colorSuccess.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline_rounded, size: 14, color: _ChatDesignSystem.colorSuccess),
            const SizedBox(width: _ChatDesignSystem.spaceXs),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorSuccess)),
          ],
        ),
      ),
    );
  }

  Widget _buildDmPanel() {
    if (_activeDmPeer == null) {
      return Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_ChatDesignSystem.colorDmAccent.withValues(alpha: 0.08), _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.02)]),
              border: Border(bottom: BorderSide(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.1))),
            ),
            child: const Text('Sohbet & Mesajlaşma', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white70)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
              child: Column(
                children: <Widget>[
                  Container(
                    decoration: BoxDecoration(
                      color: _ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
                      border: Border.all(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2)),
                      borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
                    ),
                    child: TextField(
                      controller: _dmSearchController,
                      onChanged: (String value) => unawaited(_searchDmUsers(value)),
                      style: const TextStyle(fontSize: 13, color: _ChatDesignSystem.colorTextPrimary),
                      decoration: InputDecoration(
                        hintText: 'Oyuncu adı ile ara...',
                        hintStyle: TextStyle(fontSize: 13, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.4)),
                        suffixIcon: _isDmSearchLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: Padding(
                                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceSm),
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_ChatDesignSystem.colorDmAccent.withValues(alpha: 0.6))),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceSm),
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_dmSearchResults.isNotEmpty) ...<Widget>[
                    const SizedBox(height: _ChatDesignSystem.spaceMd),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: _ChatDesignSystem.gradientBgPanel,
                          border: Border.all(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusLg),
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.search_rounded, size: 14, color: _ChatDesignSystem.colorDmAccent),
                                  const SizedBox(width: _ChatDesignSystem.spaceSm),
                                  Text('Arama Sonuçları (${_dmSearchResults.length})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorDmAccent)),
                                ],
                              ),
                            ),
                            ..._dmSearchResults.map((user) {
                              return GestureDetector(
                                onTap: () => _openDmConversation(user),
                                child: Container(
                                  color: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceSm),
                                  child: Row(
                                    children: <Widget>[
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(gradient: _ChatDesignSystem.gradientDm, borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd)),
                                        child: Center(child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary))),
                                      ),
                                      const SizedBox(width: _ChatDesignSystem.spaceMd),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text('@${user.username}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            if (user.displayName != null) Text(user.displayName!, style: const TextStyle(fontSize: 10, color: _ChatDesignSystem.colorTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceXs),
                                        decoration: BoxDecoration(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd)),
                                        child: Text('Yaz', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorDmAccent)),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: _ChatDesignSystem.spaceMd),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _ChatDesignSystem.gradientBgPanel,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
                        boxShadow: _ChatDesignSystem.shadowMd,
                      ),
                      child: _isDmLoading
                          ? const Center(child: SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2)))
                          : _dmConversations.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Icon(Icons.mail_outline_rounded, size: 48, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.3)),
                                      const SizedBox(height: _ChatDesignSystem.spaceMd),
                                      Text('Henüz sohbet yok', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorTextTertiary)),
                                      const SizedBox(height: _ChatDesignSystem.spaceXs),
                                      Text('Oyuncu arayarak mesaj başlat', style: TextStyle(fontSize: 11, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6))),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                                  itemCount: _dmConversations.length,
                                  separatorBuilder: (BuildContext context, int index) => const SizedBox(height: _ChatDesignSystem.spaceSm),
                                  itemBuilder: (BuildContext context, int idx) => _buildDmConversationCard(_dmConversations[idx]),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_ChatDesignSystem.colorDmAccent.withValues(alpha: 0.12), _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.04)]),
            border: Border(bottom: BorderSide(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15))),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(gradient: _ChatDesignSystem.gradientDm, borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd)),
                child: Center(child: Text(_activeDmPeer!.username.isNotEmpty ? _activeDmPeer!.username[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary))),
              ),
              const SizedBox(width: _ChatDesignSystem.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('@${_activeDmPeer!.username}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (_activeDmPeer!.displayName != null) Text(_activeDmPeer!.displayName!, style: const TextStyle(fontSize: 11, color: _ChatDesignSystem.colorTextTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _mutePlayer(_activeDmPeer!.id, playerName: _activeDmPeer!.username),
                child: Container(
                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Icon(Icons.volume_off_rounded, size: 16, color: _ChatDesignSystem.colorTextTertiary),
                ),
              ),
              const SizedBox(width: _ChatDesignSystem.spaceSm),
              GestureDetector(
                onTap: _leaveDmConversation,
                child: Container(
                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceSm),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _ChatDesignSystem.colorTextTertiary),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildMessageList()),
      ],
    );
  }

  Widget _buildDmConversationCard(_ChatDmConversation conv) {
    return GestureDetector(
      onTap: () => _openDmConversation(_ChatUserSummary(id: conv.peerUserId, username: conv.peerUsername, displayName: conv.peerDisplayName)),
      child: Container(
        padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.02)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(gradient: _ChatDesignSystem.gradientDm, borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd), border: Border.all(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.2))),
              child: Center(child: Text(conv.peerUsername.isNotEmpty ? conv.peerUsername[0].toUpperCase() : '?', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary))),
            ),
            const SizedBox(width: _ChatDesignSystem.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text('@${conv.peerUsername}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text(_formatTime(conv.lastMessageAt), style: TextStyle(fontSize: 10, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5))),
                    ],
                  ),
                  const SizedBox(height: _ChatDesignSystem.spaceXs),
                  Text(conv.lastMessageContent, style: TextStyle(fontSize: 11, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (conv.unreadCount > 0) ...<Widget>[
              const SizedBox(width: _ChatDesignSystem.spaceMd),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceSm, vertical: _ChatDesignSystem.spaceXs),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3), _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.15)]),
                    border: Border.all(color: _ChatDesignSystem.colorDmAccent.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusRound),
                  ),
                  child: Text(conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _ChatDesignSystem.colorDmAccent), textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(height: _ChatDesignSystem.spaceMd),
            Text('Mesajlar yükleniyor...', style: TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextTertiary)),
          ],
        ),
      );
    }

    final List<_ChatMessage> msgs = _currentMessages;
    if (msgs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.chat_bubble_outline_rounded, size: 56, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.2)),
            const SizedBox(height: _ChatDesignSystem.spaceLg),
            Text('Henüz mesaj yok', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ChatDesignSystem.colorTextTertiary)),
            const SizedBox(height: _ChatDesignSystem.spaceXs),
            Text('Konuşmayı başlatmak için bir mesaj yaz', style: TextStyle(fontSize: 11, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: _ChatDesignSystem.gradientBgPanel,
        borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusXl),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: msgs.length,
        padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
        itemBuilder: (BuildContext context, int i) {
          final _ChatMessage m = msgs[i];
          final bool isOwn = _isOwnSender(m.senderId);

          if (m.isSystem) {
            return Padding(
              padding: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceMd),
              child: Container(
                padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_ChatDesignSystem.colorInfo.withValues(alpha: 0.12), _ChatDesignSystem.colorInfo.withValues(alpha: 0.04)]),
                  border: Border.all(color: _ChatDesignSystem.colorInfo.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded, size: 16, color: _ChatDesignSystem.colorInfo.withValues(alpha: 0.6)),
                    const SizedBox(width: _ChatDesignSystem.spaceSm),
                    Expanded(child: Text(m.content, style: TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextSecondary, fontStyle: FontStyle.italic))),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceMd),
            child: Align(
              alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: GestureDetector(
                  onLongPress: isOwn ? null : () => _mutePlayer(m.senderId, playerName: m.senderName),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isOwn
                          ? LinearGradient(colors: [_ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.15), _ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.06)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.03)]),
                      border: Border.all(color: isOwn ? _ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
                      boxShadow: [BoxShadow(color: isOwn ? _ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceSm, vertical: _ChatDesignSystem.spaceXs),
                              decoration: BoxDecoration(
                                color: isOwn ? _ChatDesignSystem.colorGlobalAccent.withValues(alpha: 0.2) : _activeChannel.accentColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusSm),
                              ),
                              child: Text(isOwn ? 'Sen' : m.senderName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOwn ? _ChatDesignSystem.colorGlobalAccent : _activeChannel.accentColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: _ChatDesignSystem.spaceSm),
                            Text(_formatTime(m.timestamp), style: TextStyle(fontSize: 9, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.6))),
                          ],
                        ),
                        const SizedBox(height: _ChatDesignSystem.spaceSm),
                        Text(m.content, style: const TextStyle(fontSize: 12, color: _ChatDesignSystem.colorTextPrimary, height: 1.4)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    final bool canSend = !_isSending && _activeBan == null && _messageController.text.trim().isNotEmpty;
    final int charCount = _messageController.text.length;

    return Container(
      padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (charCount > _maxMessageLength * 0.8)
            Padding(
              padding: const EdgeInsets.only(bottom: _ChatDesignSystem.spaceMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Text('$charCount/$_maxMessageLength', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: charCount >= _maxMessageLength ? _ChatDesignSystem.colorError : _ChatDesignSystem.colorWarning)),
                ],
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _ChatDesignSystem.colorBgSecondary.withValues(alpha: 0.5),
                    border: Border.all(
                      color: _activeBan != null ? _ChatDesignSystem.colorError.withValues(alpha: 0.3) : _activeChannel.accentColor.withValues(alpha: 0.2),
                    ),
                    borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
                  ),
                  child: TextField(
                    controller: _messageController,
                    enabled: _activeBan == null,
                    maxLength: _maxMessageLength,
                    maxLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(fontSize: 13, color: _ChatDesignSystem.colorTextPrimary),
                    decoration: InputDecoration(
                      hintText: _activeBan != null ? 'Sohbete erişiminiz kısıtlı' : _activeChannel == _ChatChannel.dm ? 'Mesaj yaz...' : '${_activeChannel.label} kanalında yaz...',
                      hintStyle: TextStyle(fontSize: 13, color: _ChatDesignSystem.colorTextTertiary.withValues(alpha: 0.4)),
                      counter: const Offstage(),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: _ChatDesignSystem.spaceMd, vertical: _ChatDesignSystem.spaceMd),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: _ChatDesignSystem.spaceMd),
              GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: Container(
                  padding: const EdgeInsets.all(_ChatDesignSystem.spaceMd),
                  decoration: BoxDecoration(
                    gradient: canSend ? LinearGradient(colors: [_activeChannel.accentColor.withValues(alpha: 0.4), _activeChannel.accentColor.withValues(alpha: 0.2)]) : LinearGradient(colors: [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]),
                    border: Border.all(color: canSend ? _activeChannel.accentColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(_ChatDesignSystem.radiusMd),
                  ),
                  child: _isSending
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_activeChannel.accentColor)))
                      : Icon(Icons.send_rounded, size: 16, color: canSend ? _activeChannel.accentColor : Colors.white.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

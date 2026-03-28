import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/supabase_service.dart';
import '../models/guild_model.dart';

class GuildState {
  const GuildState({
    this.guild,
    required this.searchResults,
    required this.isLoading,
    this.error,
  });

  final GuildData? guild;
  final List<GuildData> searchResults;
  final bool isLoading;
  final String? error;

  factory GuildState.initial() => const GuildState(
        searchResults: <GuildData>[],
        isLoading: false,
      );

  GuildState copyWith({
    GuildData? guild,
    List<GuildData>? searchResults,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearGuild = false,
  }) {
    return GuildState(
      guild: clearGuild ? null : (guild ?? this.guild),
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class GuildNotifier extends Notifier<GuildState> {
  @override
  GuildState build() => GuildState.initial();

  Future<void> loadGuild() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response =
          await SupabaseService.client.rpc('get_player_guild');

      if (response == null) {
        state = state.copyWith(isLoading: false, clearGuild: true);
        return;
      }

      final Map<String, dynamic> data = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      state = state.copyWith(
        isLoading: false,
        guild: GuildData.fromJson(data),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Lonca bilgileri yuklenirken bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<void> searchGuilds(String query) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('search_guilds', params: <String, dynamic>{
        'p_query': query,
      });

      final List<GuildData> results = (response as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(GuildData.fromJson)
          .toList();

      state = state.copyWith(isLoading: false, searchResults: results);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Lonca araması sirasinda bir hata olustu: ${e.toString()}',
      );
    }
  }

  Future<bool> createGuild({
    required String name,
    required String description,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await SupabaseService.client
          .rpc('create_guild', params: <String, dynamic>{
        'p_name': name,
        'p_description': description,
      });

      if (response != null) {
        final Map<String, dynamic> data = response is Map<String, dynamic>
            ? response
            : Map<String, dynamic>.from(response as Map);
        state = state.copyWith(
          isLoading: false,
          guild: GuildData.fromJson(data),
        );
      } else {
        state = state.copyWith(isLoading: false);
        await loadGuild();
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Lonca olusturulurken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> joinGuild(String guildId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await SupabaseService.client
          .rpc('join_guild', params: <String, dynamic>{
        'p_guild_id': guildId,
      });

      await loadGuild();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Loncaya katilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> leaveGuild() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await SupabaseService.client.rpc('leave_guild');

      state = state.copyWith(isLoading: false, clearGuild: true);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Loncadan ayrilirken bir hata olustu: ${e.toString()}',
      );
      return false;
    }
  }

  void clearSearchResults() {
    state = state.copyWith(searchResults: <GuildData>[]);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void clear() {
    state = GuildState.initial();
  }
}

final NotifierProvider<GuildNotifier, GuildState> guildProvider =
    NotifierProvider<GuildNotifier, GuildState>(GuildNotifier.new);

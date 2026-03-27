import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../screens/achievements/achievements_screen.dart';
import '../screens/auth/character_select_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/bank/bank_screen.dart';
import '../screens/building/building_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/crafting/crafting_screen.dart';
import '../screens/dungeon/dungeon_screen.dart';
import '../screens/dungeon/dungeon_battle_screen.dart';
import '../screens/enhancement/enhancement_screen.dart';
import '../screens/events/events_screen.dart';
import '../screens/facilities/facility_detail_screen.dart';
import '../screens/facilities/facilities_screen.dart';
import '../screens/guild/guild_screen.dart';
import '../screens/guild/guild_war_screen.dart';
import '../screens/guild/guild_monument_screen.dart';
import '../screens/guild/guild_monument_donate_screen.dart';
import '../screens/hospital/hospital_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/map/map_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/mekans/mekans_screen.dart';
import '../screens/mekans/mekan_detail_screen.dart';
import '../screens/mekans/mekan_arena_screen.dart';
import '../screens/mekans/mekan_create_screen.dart';
import '../screens/mekans/my_mekan_screen.dart';
import '../screens/prison/prison_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/pvp/pvp_screen.dart';
import '../screens/pvp/pvp_history_screen.dart';
import '../screens/pvp/pvp_tournament_screen.dart';
import '../screens/quests/quests_screen.dart';
import '../screens/reputation/reputation_screen.dart';
import '../screens/season/season_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/shop/shop_screen.dart';
import '../screens/trade/trade_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String inventory = '/inventory';
  static const String dungeon = '/dungeon';
  static const String character = '/character';
  static const String profile = '/profile';
  static const String hospital = '/hospital';
  static const String market = '/market';
  static const String facilities = '/facilities';

  // New routes
  static const String achievements = '/achievements';
  static const String bank = '/bank';
  static const String building = '/building';
  static const String chat = '/chat';
  static const String crafting = '/crafting';
  static const String dungeonBattle = '/dungeon/battle';
  static const String enhancement = '/enhancement';
  static const String events = '/events';
  static const String guild = '/guild';
  static const String guildWar = '/guild-war';
  static const String guildMonument = '/guild/monument';
  static const String guildMonumentDonate = '/guild/monument/donate';
  static const String leaderboard = '/leaderboard';
  static const String map = '/map';
  static const String mekans = '/mekans';
  static const String mekanCreate = '/mekans/create';
  static const String myMekan = '/my-mekan';
  static const String characterSelect = '/onboarding/character-select';
  static const String prison = '/prison';
  static const String pvp = '/pvp';
  static const String pvpHistory = '/pvp/history';
  static const String pvpTournament = '/pvp/tournament';
  static const String quests = '/quests';
  static const String reputation = '/reputation';
  static const String season = '/season';
  static const String settings = '/settings';
  static const String shop = '/shop';
  static const String trade = '/trade';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  errorBuilder: (BuildContext context, GoRouterState state) => const HomeScreen(),
  redirect: (BuildContext context, GoRouterState state) {
    final String path = state.uri.path;

    if (path == '/dungeon/' || path == '/dungeon//') {
      return AppRoutes.dungeon;
    }

    final bool hasSession = SupabaseService.isInitialized &&
        SupabaseService.client.auth.currentSession != null;

    final bool isPublicRoute =
        path == AppRoutes.splash || path == AppRoutes.login || path == AppRoutes.register;

    if (!hasSession && !isPublicRoute) {
      return AppRoutes.login;
    }

    if (hasSession && isPublicRoute) {
      return AppRoutes.home;
    }

    return null;
  },
  routes: <RouteBase>[
    GoRoute(
      path: AppRoutes.splash,
      builder: (BuildContext context, GoRouterState state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (BuildContext context, GoRouterState state) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (BuildContext context, GoRouterState state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.inventory,
      builder: (BuildContext context, GoRouterState state) => const InventoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.dungeon,
      builder: (BuildContext context, GoRouterState state) => const DungeonScreen(),
    ),
    GoRoute(
      path: AppRoutes.character,
      builder: (BuildContext context, GoRouterState state) => const CharacterScreen(),
    ),
    GoRoute(
      path: AppRoutes.profile,
      builder: (BuildContext context, GoRouterState state) => const ProfileScreen(),
    ),
    GoRoute(
      path: AppRoutes.hospital,
      builder: (BuildContext context, GoRouterState state) => const HospitalScreen(),
    ),
    GoRoute(
      path: AppRoutes.market,
      builder: (BuildContext context, GoRouterState state) => const MarketScreen(),
    ),
    GoRoute(
      path: AppRoutes.facilities,
      builder: (BuildContext context, GoRouterState state) => const FacilitiesScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.facilities}/:type',
      builder: (BuildContext context, GoRouterState state) {
        final String type = state.pathParameters['type'] ?? '';
        return FacilityDetailScreen(type: type);
      },
    ),
    // New routes
    GoRoute(
      path: AppRoutes.achievements,
      builder: (BuildContext context, GoRouterState state) => const AchievementsScreen(),
    ),
    GoRoute(
      path: AppRoutes.bank,
      builder: (BuildContext context, GoRouterState state) => const BankScreen(),
    ),
    GoRoute(
      path: AppRoutes.building,
      builder: (BuildContext context, GoRouterState state) => const BuildingScreen(),
    ),
    GoRoute(
      path: AppRoutes.chat,
      builder: (BuildContext context, GoRouterState state) => const ChatScreen(),
    ),
    GoRoute(
      path: AppRoutes.crafting,
      builder: (BuildContext context, GoRouterState state) => const CraftingScreen(),
    ),
    GoRoute(
      path: AppRoutes.dungeonBattle,
      builder: (BuildContext context, GoRouterState state) => const DungeonBattleScreen(),
    ),
    GoRoute(
      path: AppRoutes.enhancement,
      builder: (BuildContext context, GoRouterState state) => const EnhancementScreen(),
    ),
    GoRoute(
      path: AppRoutes.events,
      builder: (BuildContext context, GoRouterState state) => const EventsScreen(),
    ),
    GoRoute(
      path: AppRoutes.guild,
      builder: (BuildContext context, GoRouterState state) => const GuildScreen(),
    ),
    GoRoute(
      path: AppRoutes.guildWar,
      builder: (BuildContext context, GoRouterState state) => const GuildWarScreen(),
    ),
    GoRoute(
      path: AppRoutes.guildMonument,
      builder: (BuildContext context, GoRouterState state) => const GuildMonumentScreen(),
    ),
    GoRoute(
      path: AppRoutes.guildMonumentDonate,
      builder: (BuildContext context, GoRouterState state) => const GuildMonumentDonateScreen(),
    ),
    GoRoute(
      path: AppRoutes.leaderboard,
      builder: (BuildContext context, GoRouterState state) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: AppRoutes.map,
      builder: (BuildContext context, GoRouterState state) => const MapScreen(),
    ),
    GoRoute(
      path: AppRoutes.mekans,
      builder: (BuildContext context, GoRouterState state) => const MekansScreen(),
    ),
    GoRoute(
      path: AppRoutes.mekanCreate,
      builder: (BuildContext context, GoRouterState state) => const MekanCreateScreen(),
    ),
    GoRoute(
      path: '${AppRoutes.mekans}/:id',
      builder: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return MekanDetailScreen(mekanId: id);
      },
    ),
    GoRoute(
      path: '${AppRoutes.mekans}/:id/arena',
      builder: (BuildContext context, GoRouterState state) {
        final String id = state.pathParameters['id'] ?? '';
        return MekanArenaScreen(mekanId: id);
      },
    ),
    GoRoute(
      path: AppRoutes.myMekan,
      builder: (BuildContext context, GoRouterState state) => const MyMekanScreen(),
    ),
    GoRoute(
      path: AppRoutes.characterSelect,
      builder: (BuildContext context, GoRouterState state) => const CharacterSelectScreen(),
    ),
    GoRoute(
      path: AppRoutes.prison,
      builder: (BuildContext context, GoRouterState state) => const PrisonScreen(),
    ),
    GoRoute(
      path: AppRoutes.pvp,
      builder: (BuildContext context, GoRouterState state) => const PvpScreen(),
    ),
    GoRoute(
      path: AppRoutes.pvpHistory,
      builder: (BuildContext context, GoRouterState state) => const PvpHistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.pvpTournament,
      builder: (BuildContext context, GoRouterState state) => const PvpTournamentScreen(),
    ),
    GoRoute(
      path: AppRoutes.quests,
      builder: (BuildContext context, GoRouterState state) => const QuestsScreen(),
    ),
    GoRoute(
      path: AppRoutes.reputation,
      builder: (BuildContext context, GoRouterState state) => const ReputationScreen(),
    ),
    GoRoute(
      path: AppRoutes.season,
      builder: (BuildContext context, GoRouterState state) => const SeasonScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (BuildContext context, GoRouterState state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.shop,
      builder: (BuildContext context, GoRouterState state) => const ShopScreen(),
    ),
    GoRoute(
      path: AppRoutes.trade,
      builder: (BuildContext context, GoRouterState state) => const TradeScreen(),
    ),
  ],
);

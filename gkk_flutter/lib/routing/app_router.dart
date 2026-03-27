import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/supabase_service.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/character/character_screen.dart';
import '../screens/dungeon/dungeon_screen.dart';
import '../screens/facilities/facility_detail_screen.dart';
import '../screens/facilities/facilities_screen.dart';
import '../screens/hospital/hospital_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/inventory/inventory_screen.dart';
import '../screens/market/market_screen.dart';
import '../screens/profile/profile_screen.dart';

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
  ],
);

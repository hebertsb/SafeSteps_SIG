import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'shared/widgets/bottom_nav.dart';
import 'features/map/domain/entities/child.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/zones/presentation/zones_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/alerts/presentation/alerts_screen.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/child_login_screen.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/profile/presentation/create_child_screen.dart';
import 'features/profile/presentation/child_detail_screen.dart';
import 'features/child/presentation/child_home_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/map',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authControllerProvider.future).asStream(),
    ),
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/child-login';

      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      if (isLoggedIn) {
        final user = authState.value;
        final isChild = user?.role == 'hijo';

        // Redirect child to child home if trying to access map or auth pages
        if (isChild && (isLoggingIn || state.matchedLocation == '/map')) {
          return '/child-home';
        }

        // Redirect tutor to map if trying to access auth pages
        if (!isChild && isLoggingIn) {
          return '/map';
        }
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/child-login',
        builder: (context, state) => const ChildLoginScreen(),
      ),
      GoRoute(path: '/register', redirect: (context, state) => '/login'),

      // Child Routes
      GoRoute(
        path: '/child-home',
        builder: (context, state) => const ChildHomeScreen(),
      ),

      // Tutor Routes
      GoRoute(
        path: '/create-child',
        builder: (context, state) => const CreateChildScreen(),
      ),
      GoRoute(
        path: '/child-detail',
        builder: (context, state) {
          final child = state.extra as Child;
          return ChildDetailScreen(child: child);
        },
      ),

      // Main App Routes (Tutor)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BottomNavBar(navigationShell: navigationShell);
        },
        branches: [
          // Map Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/map',
                builder: (context, state) => const MapScreen(),
              ),
            ],
          ),
          // Zones Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/zones',
                builder: (context, state) => const ZonesScreen(),
              ),
            ],
          ),
          // Alerts Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                builder: (context, state) => const AlertsScreen(),
              ),
            ],
          ),
          // Profile Branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Helper class to convert Stream to Listenable for GoRouter refresh
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

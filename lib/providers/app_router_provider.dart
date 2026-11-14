import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/task_model.dart';
import '../screens/add_task_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/signup_screen.dart';
import 'auth_provider.dart';
import 'onboarding_service.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final onboardingService = ref.watch(onboardingServiceProvider);
  final refreshNotifier = _GoRouterRefreshStream(authService.authStateChanges);

  final router = GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isLoggedIn = authService.currentUser != null;
      final location = state.matchedLocation;
      final isOnboarding = location == '/onboarding';
      final isAuthRoute = [
        '/login',
        '/signup',
        '/forgot-password',
      ].contains(location);

      if (!onboardingService.isCompleted) {
        return isOnboarding ? null : '/onboarding';
      }

      if (isOnboarding) {
        return isLoggedIn ? '/home' : '/login';
      }

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/task',
        builder: (context, state) => AddTaskScreen(task: state.extra as Task?),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

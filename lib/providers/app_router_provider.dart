import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = FirebaseAuth.instance;

  final refreshNotifier = _GoRouterRefreshStream(auth.authStateChanges());

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,

    redirect: (context, state) {
      final isLoggedIn = auth.currentUser != null;

      final isAuthRoute = ['/login', '/signup'].contains(state.matchedLocation);

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/home';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const _PlaceholderScreen(title: 'Sign Up'),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Dashboard'),
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

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taskly')),
      body: Center(child: Text(title)),
    );
  }
}

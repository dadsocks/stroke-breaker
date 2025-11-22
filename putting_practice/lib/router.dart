import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'screens/session_screen.dart';
import 'services/auth_service.dart';

class AppRouter {
  AppRouter(this.authService);

  static const String loginRoute = '/login';
  static const String homeRoute = '/home';

  final AuthService authService;

  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homeRoute:
        final user = authService.currentUser;
        if (user == null) {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => LoginScreen(authService: authService),
          );
        }
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SessionScreen(
            authService: authService,
          ),
        );
      case loginRoute:
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => LoginScreen(authService: authService),
        );
    }
  }
}

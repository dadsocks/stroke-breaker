import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'router.dart';
import 'services/auth_service.dart';
import 'services/random_putt_generator.dart';
import 'services/session_manager.dart';
import 'services/session_storage_service.dart';
import 'services/practice_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PuttingPracticeBootstrap());
}

class PuttingPracticeBootstrap extends StatelessWidget {
  const PuttingPracticeBootstrap({super.key});

  Future<_AppDependencies> _initialize() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    return _AppDependencies(
      authService: FirebaseAuthService(),
      practiceRepository: PracticeRepository(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppDependencies>(
      future: _initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapScaffold(
            title: 'Loading',
            message: 'Setting up Firebase…',
            showProgress: true,
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _BootstrapScaffold(
            title: 'Firebase configuration required',
            message:
                'Firebase could not be initialized. Double-check GoogleService-Info.plist and bundle identifiers.',
            details: snapshot.error?.toString(),
            isError: true,
          );
        }

        return PuttingPracticeApp(
          authService: snapshot.data!.authService,
          practiceRepository: snapshot.data!.practiceRepository,
        );
      },
    );
  }
}

class PuttingPracticeApp extends StatelessWidget {
  PuttingPracticeApp({super.key, required this.authService, required this.practiceRepository})
      : _router = AppRouter(authService);

  final AuthService authService;
  final PracticeRepository practiceRepository;
  final AppRouter _router;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final manager = SessionManager(
          generator: RandomPuttGenerator(),
          storage: const SessionStorageService(),
          practiceRepository: practiceRepository,
        );
        manager.loadPersistedSession();
        return manager;
      },
      child: StreamBuilder<User?>(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user != null) {
            practiceRepository.ensureUserDocument(user);
          }
          final routeName =
              user == null ? AppRouter.loginRoute : AppRouter.homeRoute;

          return MaterialApp(
            key: ValueKey(routeName),
            title: 'Putting Practice',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade700),
              useMaterial3: true,
            ),
            initialRoute: routeName,
            onGenerateRoute: _router.onGenerateRoute,
          );
        },
      ),
    );
  }
}

class _AppDependencies {
  const _AppDependencies({required this.authService, required this.practiceRepository});

  final AuthService authService;
  final PracticeRepository practiceRepository;
}

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold({
    required this.title,
    required this.message,
    this.details,
    this.isError = false,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final String? details;
  final bool isError;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green.shade700),
      useMaterial3: true,
    ).colorScheme;

    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.cloud_sync_outlined,
                    color: isError ? colorScheme.error : colorScheme.primary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  if (details != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      details!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isError ? colorScheme.error : colorScheme.secondary,
                      ),
                    ),
                  ],
                  if (showProgress) ...[
                    const SizedBox(height: 24),
                    const CircularProgressIndicator.adaptive(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _inProgress = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _inProgress = true;
      _errorMessage = null;
    });

    try {
      final user = await widget.authService.signInWithGoogle();
      if (user == null && mounted) {
        setState(() {
          _errorMessage = 'You cancelled the sign-in flow.';
        });
      }
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _inProgress = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.golf_course_outlined,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Putting Practice',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Sign in with Google to securely store your putting stats.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: Text(_inProgress ? 'Signing in...' : 'Sign in with Google'),
                  onPressed: _inProgress ? null : _handleGoogleSignIn,
                ),
                if (_inProgress) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator.adaptive(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

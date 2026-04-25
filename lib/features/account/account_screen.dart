import 'package:annoto/app/app_state.dart';
import 'package:annoto/services/lichess_service.dart';
import 'package:annoto/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  static const routeName = '/account';

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _lichessUsernameController = TextEditingController();

  bool _loading = false;
  bool _lichessLoading = false;
  bool _lichessConnected = false;

  @override
  void initState() {
    super.initState();
    _loadLichessUsername();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lichessUsernameController.dispose();
    super.dispose();
  }

  Future<void> _loadLichessUsername() async {
    final username = await lichessService.username();

    if (!mounted || username == null) return;

    setState(() {
      _lichessUsernameController.text = username;
      _lichessConnected = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final session = appState.session;
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;
    const accountPadding = 96.0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton.filled(
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: fillColor,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 22),
        ),
        title: const Text('Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.isAuthenticated) ...[
              Text(
                session.email ?? '',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : () => _signOut(appState),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign out'),
              ),
            ] else ...[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Password'),
                onSubmitted: (_) => _signIn(appState),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : () => _signIn(appState),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign in'),
              ),
            ],
            const SizedBox(height: accountPadding),
            const Divider(),
            const SizedBox(height: 24),
            if (_lichessConnected)
              Text(
                _lichessUsernameController.text,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              )
            else
              TextField(
                controller: _lichessUsernameController,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Lichess username',
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _lichessLoading
                  ? null
                  : _lichessConnected
                      ? _disconnectLichess
                      : _authenticateLichess,
              child: _lichessLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _lichessConnected
                          ? 'Sign out of Lichess'
                          : 'Connect Lichess',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _authenticateLichess() async {
    final username = _lichessUsernameController.text.trim();

    if (username.isEmpty) {
      NotificationService.showError('Enter Lichess username.');
      return;
    }

    setState(() => _lichessLoading = true);

    try {
      await lichessService.authenticate(username);
      if (mounted) setState(() => _lichessConnected = true);
      NotificationService.showInfo('Lichess connected.');
    } catch (e) {
      NotificationService.showError(e.toString());
    } finally {
      if (mounted) setState(() => _lichessLoading = false);
    }
  }

  Future<void> _disconnectLichess() async {
    setState(() => _lichessLoading = true);

    try {
      await lichessService.disconnect();
      if (mounted) {
        setState(() {
          _lichessConnected = false;
          _lichessUsernameController.clear();
        });
      }
      NotificationService.showInfo('Lichess disconnected.');
    } catch (e) {
      NotificationService.showError(e.toString());
    } finally {
      if (mounted) setState(() => _lichessLoading = false);
    }
  }

  Future<void> _signIn(AppState appState) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      NotificationService.showError('Enter email and password.');
      return;
    }

    setState(() => _loading = true);

    try {
      await appState.signIn(email, password);
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      NotificationService.showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut(AppState appState) async {
    setState(() => _loading = true);

    try {
      await appState.signOut();
      if (mounted) Navigator.pop(context);
    } on AuthException catch (e) {
      NotificationService.showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

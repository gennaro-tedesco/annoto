import 'package:annoto/app/app_state.dart';
import 'package:annoto/models/move_pair.dart';
import 'package:annoto/repositories/scoresheet_repository.dart';
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

    _lichessUsernameController.text = username;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final session = appState.session;
    final theme = Theme.of(context);
    final fillColor =
        theme.inputDecorationTheme.fillColor ??
        theme.colorScheme.surfaceContainerHighest;

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
        child: session.isAuthenticated
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 32),
                  Text('Lichess', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lichessUsernameController,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Lichess username',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _lichessLoading ? null : _authenticateLichess,
                    child: _lichessLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Connect Lichess'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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

      final pgn = await lichessService.exportStudiesPgn(username);
      final games = splitPgnGames(pgn);

      if (games.isEmpty) {
        NotificationService.showError('No valid Lichess studies found.');
        return;
      }

      await scoresheetRepository.save(pgn, filename: 'lichess_$username.pgn');

      NotificationService.showInfo('Lichess studies imported.');
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

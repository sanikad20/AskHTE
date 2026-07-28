import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'home_shell.dart';

/// Listens to Firebase Auth state and routes to the right screen.
/// This is the real app entry point (main.dart points `home:` at
/// this widget).
///
///   no session            -> LoginScreen
///   session, has role doc -> HomeShell
///   session, no role doc  -> back to LoginScreen (interrupted signup —
///                            see AuthService.fetchUserRole)
///
/// CLEANUP: PS3 (HTE Q&A) has no user roles — HomeShell always shows
/// TechnicianHome regardless of role (see home_shell.dart) — so this
/// no longer creates/tracks a RoleController or wraps HomeShell in a
/// RoleScope; that machinery only existed to support in-app role
/// switching between industrial dashboards (Technician/Engineer/
/// Manager/Auditor) that this build doesn't use. fetchUserRole(uid)
/// is still called once per sign-in purely as an existence check —
/// its result isn't needed, but a missing role doc still means an
/// interrupted signup that should bounce back to LoginScreen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder(
          future: authService.fetchUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }
            if (roleSnapshot.hasError) {
              // Profile doc missing (interrupted signup) — sign out
              // and send back to login rather than get stuck on a
              // spinner.
              authService.signOut();
              return const LoginScreen();
            }

            return const HomeShell();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

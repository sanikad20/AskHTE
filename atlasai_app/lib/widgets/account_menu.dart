import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Sign-out menu shown in the chat screen's AppBar.
///
/// CHANGE (HTE Q&A build): dropped the `role` parameter and the
/// "Signed in as <Role>" line / role-label pill — PS3 has no user
/// roles, so surfacing "Technician" here was leftover industrial-app
/// UI with nothing behind it anymore now that HomeShell always shows
/// the same screen. Sign-out behavior is unchanged: AuthGate listens
/// to authStateChanges and routes back to LoginScreen automatically.
class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'sign_out') {
          AuthService().signOut();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 16, color: AppColors.primary),
            SizedBox(width: 6),
            Icon(Icons.expand_more, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

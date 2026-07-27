import 'package:flutter/material.dart';
import 'technician/technician_home.dart';

/// PS3 (HTE Q&A) has no user roles — every signed-in user goes
/// straight to the Q&A chat screen. This used to switch on
/// RoleScope.of(context).role to route between Technician/Engineer/
/// Manager/Auditor dashboards (see git history / the ethack_genai-main
/// repo this was forked from); those dashboards are industrial-domain
/// screens (equipment timelines, compliance audits, etc.) that don't
/// apply to an HTE circular Q&A tool, so this always shows
/// TechnicianHome (the chat screen) instead of branching.
///
/// The role-based screens/services (engineer_home.dart, manager_home.dart,
/// auditor_home.dart, role_controller.dart, role_switcher.dart) are still
/// in the codebase but no longer reachable from normal app navigation —
/// left in place rather than deleted so nothing else that imports them
/// (e.g. auth_gate.dart's RoleScope wrapper) breaks. If you want them
/// fully gone, that's a follow-up cleanup, not required for the PS3 demo.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const TechnicianHome();
  }
}

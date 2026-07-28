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
/// CLEANUP: the role-based screens/services (engineer_home.dart,
/// manager_home.dart, auditor_home.dart, equipment_timeline_screen.dart,
/// action_result_screen.dart, action_engine_service.dart,
/// dashboard_service.dart, role_controller.dart, role_switcher.dart,
/// role_badge.dart) have been removed — they were unreachable from any
/// real navigation path and specific to the industrial domain this was
/// forked from. auth_gate.dart no longer creates a RoleScope either.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const TechnicianHome();
  }
}

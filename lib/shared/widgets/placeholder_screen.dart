import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

/// Reusable placeholder displayed for every screen that is not yet implemented.
///
/// Shows the screen name, its route, a "🚧 Implementation Pending" badge,
/// and a button to return to the [ScreenNavigator].
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.screenName,
    required this.route,
  });

  final String screenName;
  final String route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: BackButton(
          color: const Color(0xFF2453FF),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.devScreens);
            }
          },
        ),
        title: Text(
          screenName,
          style: const TextStyle(
            color: Color(0xFF1A1F36),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ────────────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF3FF),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    size: 48,
                    color: Color(0xFF2453FF),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Screen name ─────────────────────────────────────────────
                Text(
                  screenName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1A1F36),
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Route badge ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCDD5FF)),
                  ),
                  child: Text(
                    route,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFF3D52CC),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Status badge ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFD980)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🚧', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Implementation Pending',
                        style: TextStyle(
                          color: Color(0xFF8A6400),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Description ──────────────────────────────────────────────
                Text(
                  'This page is created as a placeholder and will be\nimplemented in a future sprint.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // ── Back button ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.devScreens);
                      }
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 18),
                    label: const Text('Back to Screen Navigator'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2453FF),
                      side: const BorderSide(color: Color(0xFF2453FF)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

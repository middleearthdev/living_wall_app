import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Placeholder until week 4. Reachable from S04 success and from router
/// redirect when at least one wall exists.
class DashboardPlaceholderScreen extends StatelessWidget {
  const DashboardPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Wall tersambung', style: theme.textTheme.displaySmall),
                const SizedBox(height: 12),
                Text(
                  'Dashboard hadir di sprint week 4.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: ext.textDim,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

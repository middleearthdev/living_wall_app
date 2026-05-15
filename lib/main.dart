import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';

void main() {
  runApp(const ProviderScope(child: LivingWallApp()));
}

class LivingWallApp extends StatelessWidget {
  const LivingWallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Living Wall',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _ThemePreviewScreen(),
    );
  }
}

/// Temporary preview to verify theme tokens render correctly.
/// Replaced by the router + onboarding/dashboard in later sprints.
class _ThemePreviewScreen extends StatelessWidget {
  const _ThemePreviewScreen();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<LivingWallTheme>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Living Wall', style: text.displayMedium),
              const SizedBox(height: 8),
              Text('theme preview', style: TextStyle(color: ext.textDim)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _swatch('tenang', ext.tenang),
                  _swatch('fokus', ext.fokus),
                  _swatch('sosial', ext.sosial),
                  _swatch('dinamis', ext.dinamis),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ext.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ext.surface3),
                ),
                child: Text(
                  'Accent periwinkle',
                  style: text.headlineSmall?.copyWith(color: ext.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _swatch(String label, Color color) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.ink),
      ),
    );
  }
}

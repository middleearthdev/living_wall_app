import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/app_theme.dart';

/// Shared chrome for the wifi → discovery → name flow. Used by both
/// onboarding (S02–S04) and add-wall (Sub-A/Sub-B). The optional [topBar]
/// slot replaces the step pill when an add-wall screen wants the
/// "‹ Tambah Wall ✕" header instead; [contextBanner] sits below it to call
/// out "akan masuk ke {room}" when the destination room is locked in.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.stepLabel,
    this.topBar,
    this.contextBanner,
    required this.title,
    this.subtitle,
    required this.body,
    this.primaryAction,
    this.secondaryAction,
  }) : assert(
         stepLabel != null || topBar != null,
         'Provide either a step pill label or a top bar — chrome must have one',
       );

  /// Onboarding mode pill ("LANGKAH 1 / 3"). Pass null when [topBar] is set.
  final String? stepLabel;

  /// Add-wall mode header. Renders in place of the step pill.
  final Widget? topBar;

  /// Optional row shown below the header — used by add-wall to signal the
  /// locked target room.
  final Widget? contextBanner;

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topBar != null) topBar! else _StepPill(label: stepLabel!),
              if (contextBanner != null) ...[
                const SizedBox(height: 14),
                contextBanner!,
              ],
              const SizedBox(height: 24),
              Text(title, style: theme.textTheme.displaySmall),
              if (subtitle != null) ...[
                const SizedBox(height: 12),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: ext.textDim,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Expanded(child: body),
              if (secondaryAction != null) ...[
                SizedBox(width: double.infinity, child: secondaryAction!),
                const SizedBox(height: 8),
              ],
              if (primaryAction != null)
                SizedBox(width: double.infinity, child: primaryAction!),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<LivingWallTheme>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ext.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ext.surface3),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: ext.accent,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Filled CTA in the brand accent. Sized to be the bottom action by default.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.ink,
              ),
            )
          : Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
    );
  }
}

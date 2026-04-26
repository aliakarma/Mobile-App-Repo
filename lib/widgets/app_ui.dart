import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.s16,
      vertical: AppSpacing.s8,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: margin,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}

class LabelChip extends StatelessWidget {
  const LabelChip({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.textColor = Colors.white,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      backgroundColor: backgroundColor,
      label: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.icon,
  });

  final String title;
  final String subtitle;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final hasSecondary =
        secondaryActionLabel != null && onSecondaryAction != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 56,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s8,
              children: [
                ElevatedButton(
                  onPressed: onPrimaryAction,
                  child: Text(primaryActionLabel),
                ),
                if (hasSecondary)
                  OutlinedButton(
                    onPressed: onSecondaryAction,
                    child: Text(secondaryActionLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Something went wrong',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AppCard(
        margin: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
            const SizedBox(height: AppSpacing.s8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.s16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

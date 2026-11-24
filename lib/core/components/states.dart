import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// Friendly "nothing here yet" placeholder with an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.tint(AppColors.primary, 0.08), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppText.cardTitle, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: AppText.body.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              AppButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error placeholder with retry.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'We couldn\'t load this right now. Please try again.',
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.tint(AppColors.danger, 0.08), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.danger),
            ),
            const SizedBox(height: 20),
            Text(title, style: AppText.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(message, style: AppText.body.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton.secondary(label: retryLabel, icon: Icons.refresh_rounded, onPressed: onRetry, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered spinner, optionally with a caption.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: AppText.label),
          ],
        ],
      ),
    );
  }
}

/// Shimmer-free skeleton block used while content "loads".
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({super.key, this.height = 80, this.width, this.radius = 16});
  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFE2E2E2), const Color(0xFFF1F1F1), _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Floating snackbars with consistent success / error / info styling.
abstract final class AppSnack {
  static void _show(BuildContext context, String message, IconData icon, Color color) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_rounded, const Color(0xFF4ADE80));

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_rounded, const Color(0xFFF87171));

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_rounded, AppColors.accent);
}

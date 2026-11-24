import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/widgets/app_logo.dart';
import '../auth/auth_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), _next);
  }

  Future<void> _next() async {
    if (!mounted) return;
    // With a valid previous session this loads the data and goes straight in; otherwise it is a no-op.
    await ref.read(authProvider.notifier).restoreSession();
    if (!mounted) return;
    final auth = ref.read(authProvider);
    context.go(auth.loggedIn ? Routes.home : (auth.onboarded ? Routes.login : Routes.onboarding));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLogo(size: 88, onDark: true),
                const SizedBox(height: 32),
                Text('ADVIO', style: AppText.wordmark(30, color: Colors.white)),
                const SizedBox(height: 14),
                Text(
                  'FOUNDER-LED WEB & SOFTWARE STUDIO',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.6, fontSize: 11),
                ),
                const SizedBox(height: 56),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: const CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../auth/auth_providers.dart';

class _Slide {
  const _Slide(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _slides = [
  _Slide(Icons.hub_rounded, AppColors.primary, 'Everything in one place',
      'Leads, clients, projects, delivery checklists, invoices and expenses for the whole ADVIO team, instead of ten different tools.'),
  _Slide(Icons.radar_rounded, AppColors.secondary, 'Never miss a follow-up',
      'Every enquiry gets an owner and a follow-up, so nothing from the website, WhatsApp or Instagram slips through.'),
  _Slide(Icons.insights_rounded, AppColors.success, 'Know your numbers',
      'Clear invoices and milestone payments, with revenue, expenses and profit visible at a glance.'),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(authProvider.notifier).finishOnboarding();
    context.go(Routes.login);
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
                    child: AnimatedOpacity(
                      opacity: last ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(onPressed: last ? null : _finish, child: const Text('Skip')),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page ? AppColors.primary : AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  child: AppButton(label: last ? 'Get started' : 'Next', onPressed: _next),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: AppColors.tint(slide.color, 0.08), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(color: AppColors.tint(slide.color, 0.14), shape: BoxShape.circle),
              child: Icon(slide.icon, size: 60, color: slide.color),
            ),
          ),
          const SizedBox(height: 48),
          Text(slide.title, style: AppText.pageTitle, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(slide.body, style: AppText.bodyLarge.copyWith(color: AppColors.muted), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Short cross-fade used when switching between the five bottom-navigation tabs,
/// so tab changes don't animate like pushing a new screen.
CustomTransitionPage<void> fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondary, child) =>
        FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
  );
}

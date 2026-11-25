import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import '../../data/repositories/save_failures.dart';
import '../../features/auth/session_loader.dart';
import '../constants/app_spacing.dart';
import 'app_button.dart';
import 'states.dart';

/// Max content width so layouts stay tidy on tablets / landscape.
const double kMaxContentWidth = 720;

/// Standard page: optional large title (tab roots) or app bar (sub pages),
/// scrollable padded content, optional pull-to-refresh and FAB.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.large = false,
    this.actions = const [],
    this.children = const [],
    this.header,
    this.fab,
    this.onRefresh,
    this.padding,
    this.bottomPadding = 96,
    this.sliver,
  });

  final String title;
  final String? subtitle;

  /// Large in-body title (primary tab roots) instead of an app bar.
  final bool large;
  final List<Widget> actions;
  final List<Widget> children;

  /// Sticky area pinned under the title (search + filters). Not scrolled.
  final Widget? header;
  final Widget? fab;
  final Future<void> Function()? onRefresh;
  final EdgeInsets? padding;
  final double bottomPadding;
  final Widget? sliver;

  @override
  Widget build(BuildContext context) {
    final pad = padding ?? const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 0);

    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: pad.copyWith(bottom: bottomPadding),
      children: [
        if (large) _LargeTitle(title: title, subtitle: subtitle, actions: actions),
        ...children,
      ],
    );

    if (onRefresh != null) {
      list = RefreshIndicator(color: AppColors.primary, onRefresh: onRefresh!, child: list);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: large
          ? null
          : AppBar(
              title: Text(title),
              actions: [...actions, const SizedBox(width: 8)],
            ),
      floatingActionButton: fab,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                if (header != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 4, AppSpacing.page, 12),
                    child: header,
                  ),
                Expanded(child: list),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LargeTitle extends StatelessWidget {
  const _LargeTitle({required this.title, this.subtitle, required this.actions});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.pageTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: AppText.body.copyWith(color: AppColors.muted)),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Pull-to-refresh: reloads everything from the database (or just pauses briefly on sample data).
Future<void> pullToRefresh(BuildContext context) async {
  final refresh = ProviderScope.containerOf(context).read(dataRefreshProvider);
  try {
    await refresh();
    if (context.mounted) AppSnack.info(context, 'Up to date');
  } on RepositoryException catch (e) {
    if (context.mounted) AppSnack.error(context, e.message);
  }
}

/// Scaffold for create/edit forms: validates, shows a saving state, pops with a success message.
class FormPage extends StatefulWidget {
  const FormPage({
    super.key,
    required this.title,
    required this.children,
    required this.onSubmit,
    this.submitLabel = 'Save',
    this.successMessage = 'Saved',
    this.formKey,
    this.extraAction,
  });

  final String title;
  final List<Widget> children;

  /// Called after validation passes. Return `false` to keep the form open.
  final FutureOr<bool?> Function() onSubmit;
  final String submitLabel;
  final String successMessage;
  final GlobalKey<FormState>? formKey;

  /// Optional secondary button shown beside the submit button.
  final Widget? extraAction;

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  late final GlobalKey<FormState> _key = widget.formKey ?? GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // A message left over from the previous screen would sit on top of the Save button.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final ok = await widget.onSubmit();
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == false) return;
    AppSnack.success(context, widget.successMessage);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _key,
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 24),
                      children: widget.children,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      if (widget.extraAction != null) ...[Expanded(child: widget.extraAction!), const SizedBox(width: 12)],
                      Expanded(
                        flex: widget.extraAction != null ? 1 : 1,
                        child: AppButton(label: widget.submitLabel, onPressed: _submit, loading: _saving),
                      ),
                    ],
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

/// Vertical gap between form fields.
class FormGap extends StatelessWidget {
  const FormGap({super.key, this.height = 20});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Bold group heading inside a long form.
class FormSectionTitle extends StatelessWidget {
  const FormSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Text(text, style: AppText.sectionTitle),
      );
}

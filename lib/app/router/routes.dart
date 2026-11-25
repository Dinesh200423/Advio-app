import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// All route paths in one place so screens never hard-code strings.
abstract final class Routes {
  // Public
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const signup = '/signup';
  static const changePassword = '/change-password';

  // Primary tabs
  static const home = '/home';
  static const leads = '/leads';
  static const projects = '/projects';
  static const finance = '/finance';
  static const more = '/more';

  // More section
  static const clients = '/clients';
  static const tasks = '/tasks';
  static const quotations = '/quotations';
  static const expenses = '/expenses';
  static const support = '/support';
  static const automation = '/automation';
  static const reports = '/reports';
  static const settings = '/settings';

  // Other
  static const invoices = '/invoices';
  static const payments = '/payments';
  static const notifications = '/notifications';

  // Detail / form helpers
  static String lead(String id) => '/leads/$id';
  static String leadEdit(String id) => '/leads/$id/edit';
  static const leadNew = '/leads/new';
  static const leadQuickAdd = '/leads/quick';

  static String client(String id) => '/clients/$id';
  static String clientEdit(String id) => '/clients/$id/edit';
  static const clientNew = '/clients/new';

  static String project(String id) => '/projects/$id';
  static String projectEdit(String id) => '/projects/$id/edit';
  static String projectNew({String? clientId}) => '/projects/new${_q({'clientId': clientId})}';

  static String task(String id) => '/tasks/$id';
  static String taskEdit(String id) => '/tasks/$id/edit';
  static String taskNew({String? projectId}) => '/tasks/new${_q({'projectId': projectId})}';

  static String quotation(String id) => '/quotations/$id';
  static String quotationEdit(String id) => '/quotations/$id/edit';
  static String quotationPreview(String id) => '/quotations/$id/preview';
  static String quotationNew({String? clientId}) => '/quotations/new${_q({'clientId': clientId})}';

  static String invoice(String id) => '/invoices/$id';
  static String invoiceEdit(String id) => '/invoices/$id/edit';
  static String invoicePreview(String id) => '/invoices/$id/preview';
  static String invoicePayment(String id) => '/invoices/$id/payment';
  static String invoiceNew({String? clientId, String? projectId}) =>
      '/invoices/new${_q({'clientId': clientId, 'projectId': projectId})}';

  static String expense(String id) => '/expenses/$id';
  static String expenseEdit(String id) => '/expenses/$id/edit';
  static const expenseNew = '/expenses/new';

  static String ticket(String id) => '/support/$id';
  static String ticketEdit(String id) => '/support/$id/edit';
  static String ticketNew({String? clientId}) => '/support/new${_q({'clientId': clientId})}';

  static const team = '/team';
  static const teamNew = '/team/new';
  static String member(String id) => '/team/$id';
  static String memberEdit(String id) => '/team/$id/edit';

  static const checklists = '/checklists';
  static String checklist(String id) => '/checklists/$id';
  static const templates = '/checklists/templates';
  static const templateNew = '/checklists/templates/new';
  static String template(String id) => '/checklists/templates/$id';

  static const settingsProfile = '/settings/profile';
  static const settingsBusiness = '/settings/business';
  static const settingsCurrency = '/settings/currency';
  static const settingsNotifications = '/settings/notifications';
  static const settingsAppearance = '/settings/appearance';
  static const settingsAbout = '/settings/about';

  static String _q(Map<String, String?> params) {
    final entries = params.entries.where((e) => e.value != null).map((e) => '${e.key}=${e.value}');
    return entries.isEmpty ? '' : '?${entries.join('&')}';
  }

  /// Primary tab roots, where the global quick-action button is shown.
  static const tabRoots = [home, leads, projects, finance, more];

  /// Which bottom-nav tab (0-4) owns [path].
  static int tabIndexFor(String path) {
    bool under(String root) => path == root || path.startsWith('$root/');
    if (under(home) || under(notifications)) return 0;
    if (under(leads)) return 1;
    if (under(projects)) return 2;
    if (under(finance) || under(invoices) || under(payments)) return 3;
    return 4;
  }
}

/// Pops if there is history, otherwise goes to [fallback].
extension SafePop on BuildContext {
  void popOr(String fallback) => canPop() ? pop() : go(fallback);
}

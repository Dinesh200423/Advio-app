import 'team.dart';

/// An area of the app that can be switched on or off for each team member.
/// The names are stored in the database (team_members.modules), so do not rename them.
enum AppModule {
  leads('Leads', 'Enquiries and prospects'),
  clients('Clients', 'Client list and details'),
  projects('Projects', 'Client projects'),
  tasks('Tasks', 'To-dos and assignments'),
  checklists('Delivery checklists', 'Project delivery steps'),
  quotations('Quotations', 'Quotes sent to clients'),
  invoices('Invoices and payments', 'Billing and money received'),
  expenses('Expenses', 'What the business spends'),
  support('Support and maintenance', 'Tickets and maintenance plans'),
  automation('Automation', 'Rules that run on their own'),
  reports('Reports', 'Summaries and charts');

  const AppModule(this.label, this.description);
  final String label;
  final String description;

  /// Modules where work is assigned to a person. Someone with the module switched off can still see
  /// (but not change) the items assigned to them.
  bool get hasAssignedItems => this == leads || this == tasks || this == support;

  /// What a new member of this role starts with. The founder can change it per person afterwards.
  static Set<AppModule> defaultsFor(TeamRole role) => switch (role) {
        TeamRole.founder => values.toSet(),
        TeamRole.sales => {leads, clients, projects, tasks, checklists, quotations, invoices, support, reports},
        TeamRole.support => {clients, projects, tasks, checklists, support, reports},
        TeamRole.developer || TeamRole.designer => {clients, projects, tasks, checklists, support},
      };
}

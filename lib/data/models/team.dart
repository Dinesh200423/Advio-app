import 'modules.dart';

enum TeamRole {
  founder('Founder'),
  developer('Developer'),
  designer('Designer'),
  sales('Sales'),
  support('Support');

  const TeamRole(this.label);
  final String label;
}

/// Someone who works at ADVIO. Tasks, leads, projects, tickets and checklist
/// items are assigned to members by id.
class TeamMember {
  /// [modules] defaults to what the role normally gets. The founder always has every module.
  TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.email = '',
    this.phone = '',
    this.active = true,
    this.hasLogin = false,
    Set<AppModule>? modules,
  }) : modules = modules ?? AppModule.defaultsFor(role);

  final String id;
  final String name;
  final TeamRole role;
  final String email;
  final String phone;

  /// Inactive members keep their history but can no longer be assigned new work.
  final bool active;
  final DateTime joinedAt;

  /// Which areas of the app this person may use. See [canUse].
  final Set<AppModule> modules;

  /// Whether a login (email and password) is linked to this member. Set by the server, never by the app.
  final bool hasLogin;

  bool canUse(AppModule module) => role == TeamRole.founder || modules.contains(module);

  String get firstName => name.trim().split(' ').first;

  TeamMember copyWith({String? name, TeamRole? role, String? email, String? phone, bool? active, Set<AppModule>? modules}) => TeamMember(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        joinedAt: joinedAt,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        active: active ?? this.active,
        hasLogin: hasLogin,
        modules: modules ?? this.modules,
      );
}

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
  const TeamMember({
    required this.id,
    required this.name,
    required this.role,
    required this.joinedAt,
    this.email = '',
    this.phone = '',
    this.active = true,
  });

  final String id;
  final String name;
  final TeamRole role;
  final String email;
  final String phone;

  /// Inactive members keep their history but can no longer be assigned new work.
  final bool active;
  final DateTime joinedAt;

  String get firstName => name.trim().split(' ').first;

  TeamMember copyWith({String? name, TeamRole? role, String? email, String? phone, bool? active}) => TeamMember(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        joinedAt: joinedAt,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        active: active ?? this.active,
      );
}

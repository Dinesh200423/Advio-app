import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock/mock_team.dart';
import '../../data/models/enums.dart';
import '../../data/models/team.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';

class TeamNotifier extends CrudNotifier<TeamMember> {
  @override
  Repository<TeamMember> get repository => ref.read(teamRepositoryProvider);
  @override
  String idOf(TeamMember item) => item.id;

  void add(TeamMember member) {
    upsert(member);
    ref.read(activityProvider.notifier).log('Team member added', detail: '${member.name} · ${member.role.label}', kind: ActivityKind.client);
  }

  void setActive(String id, bool active) => modify(id, (m) => m.copyWith(active: active));

  /// Find the member for a signed-in account by email, or create one. Returns its id.
  String registerAccount({required String name, required String email}) {
    final clean = email.trim().toLowerCase();
    for (final m in state) {
      if (clean.isNotEmpty && m.email.toLowerCase() == clean) return m.id;
    }
    final member = TeamMember(
      id: 'tm_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      role: state.isEmpty ? TeamRole.founder : TeamRole.developer,
      email: email.trim(),
      joinedAt: DateTime.now(),
    );
    add(member);
    return member.id;
  }
}

final teamProvider = NotifierProvider<TeamNotifier, List<TeamMember>>(TeamNotifier.new);

/// Everyone who can be given new work.
final activeMembersProvider = Provider<List<TeamMember>>((ref) => ref.watch(teamProvider).where((m) => m.active).toList());

final memberProvider = Provider.family<TeamMember?, String?>((ref, id) {
  if (id == null) return null;
  for (final m in ref.watch(teamProvider)) {
    if (m.id == id) return m;
  }
  return null;
});

/// Display name for an assignee id: the member's name, or "Unassigned".
final memberNameProvider = Provider.family<String, String?>((ref, id) => ref.watch(memberProvider(id))?.name ?? 'Unassigned');

/// Who is using the app. Until real accounts exist (phase 2) this can be switched from the Team screen
/// to try assignment from another person's point of view.
class CurrentMemberNotifier extends Notifier<String> {
  @override
  String build() => MockTeam.founderId;

  void switchTo(String memberId) => state = memberId;
}

final currentMemberIdProvider = NotifierProvider<CurrentMemberNotifier, String>(CurrentMemberNotifier.new);

final currentMemberProvider = Provider<TeamMember?>((ref) => ref.watch(memberProvider(ref.watch(currentMemberIdProvider))));

/// Record in the activity feed that work was handed to someone else.
/// Assigning something to yourself is not worth announcing.
void logAssignment(Ref ref, {required String what, required String title, required ActivityKind kind, String? from, String? to}) {
  if (to == null || to == from || to == ref.read(currentMemberIdProvider)) return;
  final name = ref.read(teamProvider.notifier).byId(to)?.name ?? 'a teammate';
  ref.read(activityProvider.notifier).log('$what assigned to $name', detail: title, kind: kind);
}

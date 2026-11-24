import '../models/team.dart';
import 'mock_crm.dart';

/// Sample team so assignment can be tried out. Replace with the real people in the Team screen.
abstract final class MockTeam {
  /// The member the app starts signed in as.
  static const founderId = 'tm1';

  static List<TeamMember> members() => [
        TeamMember(id: founderId, name: 'Dinesh', role: TeamRole.founder, phone: '+91 89391 27720', joinedAt: day(-400)),
        TeamMember(id: 'tm2', name: 'Priya', role: TeamRole.developer, joinedAt: day(-200)),
        TeamMember(id: 'tm3', name: 'Rishi', role: TeamRole.designer, joinedAt: day(-180)),
        TeamMember(id: 'tm4', name: 'Meena', role: TeamRole.sales, joinedAt: day(-120)),
        TeamMember(id: 'tm5', name: 'Karthik', role: TeamRole.support, joinedAt: day(-90)),
      ];
}

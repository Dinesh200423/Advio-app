import 'enums.dart';

class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.name,
    required this.trigger,
    required this.action,
    required this.kind,
    this.enabled = true,
    this.runs = 0,
    this.lastRun,
  });

  final String id;
  final String name;
  final String trigger;
  final String action;
  final AutomationKind kind;
  final bool enabled;
  final int runs;
  final DateTime? lastRun;

  AutomationRule copyWith({bool? enabled}) => AutomationRule(
        id: id,
        name: name,
        trigger: trigger,
        action: action,
        kind: kind,
        enabled: enabled ?? this.enabled,
        runs: runs,
        lastRun: lastRun,
      );
}

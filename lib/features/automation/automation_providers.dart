import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/automation_rule.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';

class AutomationNotifier extends CrudNotifier<AutomationRule> {
  @override
  Repository<AutomationRule> get repository => ref.read(automationRepositoryProvider);
  @override
  String idOf(AutomationRule item) => item.id;

  void toggle(String id, bool enabled) => modify(id, (r) => r.copyWith(enabled: enabled));

  bool isEnabled(AutomationKind kind) => state.any((r) => r.kind == kind && r.enabled);
}

final automationProvider = NotifierProvider<AutomationNotifier, List<AutomationRule>>(AutomationNotifier.new);

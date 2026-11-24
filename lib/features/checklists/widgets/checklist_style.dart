import 'package:flutter/material.dart';

import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/checklist.dart';

extension ChecklistItemStatusStyle on ChecklistItemStatus {
  Color get color => switch (this) {
        ChecklistItemStatus.todo => AppColors.muted,
        ChecklistItemStatus.doing => AppColors.primary,
        ChecklistItemStatus.waitingClient => AppColors.warning,
        ChecklistItemStatus.done => AppColors.success,
        ChecklistItemStatus.skipped => AppColors.secondary,
        ChecklistItemStatus.notApplicable => AppColors.muted,
      };

  /// One line explaining when to use the status.
  String get hint => switch (this) {
        ChecklistItemStatus.todo => 'Not started yet',
        ChecklistItemStatus.doing => 'You are working on it now',
        ChecklistItemStatus.waitingClient => 'Blocked until the client responds',
        ChecklistItemStatus.done => 'Finished (evidence added if required)',
        ChecklistItemStatus.skipped => 'Not doing it this time. A reason is needed',
        ChecklistItemStatus.notApplicable => 'Does not apply to this project. Ignored in progress',
      };

  Widget get badge => StatusBadge(label: label, color: color);
}

extension StageStatusStyle on StageStatus {
  Color get color => switch (this) {
        StageStatus.notStarted => AppColors.muted,
        StageStatus.inProgress => AppColors.primary,
        StageStatus.blocked => AppColors.danger,
        StageStatus.completed => AppColors.success,
      };

  Widget get badge => StatusBadge(label: label, color: color);
}

extension ProjectChecklistStyle on ProjectChecklist {
  /// Blue while in flight, green when finished. Being blocked is shown by the
  /// badge, not by alarm colours: waiting on a client is not a failure.
  Color get progressColor => isComplete ? AppColors.success : AppColors.primary;
}

extension EvidenceTypeText on EvidenceType {
  /// "Live website URL (URL)", "Approval document (file)", etc.
  String requirement(String hint) {
    final what = hint.isEmpty ? label : hint;
    return switch (this) {
      EvidenceType.none => 'No evidence required',
      EvidenceType.url => '$what (URL)',
      EvidenceType.file => '$what (file)',
      EvidenceType.note => '$what (note)',
    };
  }
}

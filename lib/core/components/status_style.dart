import 'package:flutter/material.dart';

import '../../data/models/enums.dart';
import '../constants/app_colors.dart';
import 'status_badge.dart';

/// UI styling (colour / icon) for domain enums. Keeps the data layer UI-free
/// and guarantees the same status always looks the same across the app.

extension LeadStatusStyle on LeadStatus {
  Color get color => switch (this) {
        LeadStatus.newLead => AppColors.primary,
        LeadStatus.contacted => AppColors.muted,
        LeadStatus.followUp => AppColors.warning,
        LeadStatus.proposalSent => AppColors.secondary,
        LeadStatus.negotiation => AppColors.primary,
        LeadStatus.won => AppColors.success,
        LeadStatus.lost => AppColors.danger,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension LeadSourceStyle on LeadSource {
  IconData get icon => switch (this) {
        LeadSource.website => Icons.language_rounded,
        LeadSource.whatsapp => Icons.chat_bubble_outline_rounded,
        LeadSource.instagram => Icons.photo_camera_outlined,
        LeadSource.referral => Icons.group_add_rounded,
        LeadSource.linkedin => Icons.work_outline_rounded,
        LeadSource.upwork => Icons.laptop_mac_rounded,
        LeadSource.coldOutreach => Icons.mail_outline_rounded,
        LeadSource.googleMaps => Icons.place_outlined,
        LeadSource.directory => Icons.menu_book_outlined,
        LeadSource.other => Icons.more_horiz_rounded,
      };
}

extension FollowUpTypeStyle on FollowUpType {
  IconData get icon => switch (this) {
        FollowUpType.call => Icons.call_rounded,
        FollowUpType.email => Icons.mail_rounded,
        FollowUpType.meeting => Icons.videocam_rounded,
        FollowUpType.whatsapp => Icons.chat_bubble_rounded,
      };
}

extension ClientStatusStyle on ClientStatus {
  Color get color => this == ClientStatus.active ? AppColors.success : AppColors.muted;
  Widget get badge => StatusBadge(label: label, color: color);
}

extension ProjectStatusStyle on ProjectStatus {
  Color get color => switch (this) {
        ProjectStatus.planned => AppColors.muted,
        ProjectStatus.active => AppColors.primary,
        ProjectStatus.onHold => AppColors.warning,
        ProjectStatus.completed => AppColors.success,
        ProjectStatus.cancelled => AppColors.danger,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension TaskStatusStyle on TaskStatus {
  Color get color => switch (this) {
        TaskStatus.todo => AppColors.muted,
        TaskStatus.inProgress => AppColors.primary,
        TaskStatus.blocked => AppColors.danger,
        TaskStatus.completed => AppColors.success,
      };
  IconData get icon => switch (this) {
        TaskStatus.todo => Icons.radio_button_unchecked_rounded,
        TaskStatus.inProgress => Icons.timelapse_rounded,
        TaskStatus.blocked => Icons.block_rounded,
        TaskStatus.completed => Icons.check_circle_rounded,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension PriorityStyle on Priority {
  Color get color => switch (this) {
        Priority.low => AppColors.muted,
        Priority.medium => AppColors.primary,
        Priority.high => AppColors.warning,
        Priority.urgent => AppColors.danger,
      };
  Widget get badge => StatusBadge(label: label, color: color, icon: Icons.flag_rounded);
}

extension QuotationStatusStyle on QuotationStatus {
  Color get color => switch (this) {
        QuotationStatus.draft => AppColors.muted,
        QuotationStatus.sent => AppColors.primary,
        QuotationStatus.accepted => AppColors.success,
        QuotationStatus.rejected => AppColors.danger,
        QuotationStatus.expired => AppColors.warning,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension InvoiceStatusStyle on InvoiceStatus {
  Color get color => switch (this) {
        InvoiceStatus.draft => AppColors.muted,
        InvoiceStatus.sent => AppColors.primary,
        InvoiceStatus.partiallyPaid => AppColors.secondary,
        InvoiceStatus.paid => AppColors.success,
        InvoiceStatus.overdue => AppColors.danger,
        InvoiceStatus.voided => AppColors.muted,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension ExpenseCategoryStyle on ExpenseCategory {
  /// Distinct-but-on-brand colours so category charts remain readable.
  Color get color => switch (this) {
        ExpenseCategory.software => AppColors.primary,
        ExpenseCategory.hardware => const Color(0xFF8A8A8A),
        ExpenseCategory.marketing => AppColors.secondary,
        ExpenseCategory.travel => AppColors.warning,
        ExpenseCategory.office => AppColors.success,
        ExpenseCategory.subscriptions => const Color(0xFFB5B5B5),
        ExpenseCategory.education => const Color(0xFF4B5563),
        ExpenseCategory.taxes => AppColors.danger,
        ExpenseCategory.other => AppColors.muted,
      };
}

extension TicketStatusStyle on TicketStatus {
  Color get color => switch (this) {
        TicketStatus.open => AppColors.primary,
        TicketStatus.inProgress => AppColors.secondary,
        TicketStatus.waiting => AppColors.warning,
        TicketStatus.resolved => AppColors.success,
        TicketStatus.closed => AppColors.muted,
      };
  Widget get badge => StatusBadge(label: label, color: color);
}

extension ActivityKindStyle on ActivityKind {
  Color get color => switch (this) {
        ActivityKind.lead => AppColors.primary,
        ActivityKind.client => AppColors.primary,
        ActivityKind.project => AppColors.primary,
        ActivityKind.task => AppColors.primary,
        ActivityKind.quotation => AppColors.secondary,
        ActivityKind.invoice => AppColors.warning,
        ActivityKind.payment => AppColors.success,
        ActivityKind.expense => AppColors.danger,
        ActivityKind.support => AppColors.warning,
        ActivityKind.note => AppColors.muted,
        ActivityKind.automation => AppColors.secondary,
      };
}


import 'common.dart';
import 'enums.dart';

class Ticket {
  const Ticket({
    required this.id,
    required this.number,
    required this.title,
    required this.clientId,
    required this.createdAt,
    this.description = '',
    this.priority = Priority.medium,
    this.status = TicketStatus.open,
    this.assigneeId,
    this.notes = const [],
  });

  final String id;
  final String number;
  final String title;
  final String clientId;
  final String description;
  final Priority priority;
  final TicketStatus status;
  final DateTime createdAt;

  /// Team member handling the ticket; null means unassigned.
  final String? assigneeId;

  /// Notes and resolution history, oldest first.
  final List<Note> notes;

  Ticket copyWith({
    String? title,
    String? clientId,
    String? description,
    Priority? priority,
    TicketStatus? status,
    Object? assigneeId = _unset,
    List<Note>? notes,
  }) =>
      Ticket(
        id: id,
        number: number,
        title: title ?? this.title,
        clientId: clientId ?? this.clientId,
        description: description ?? this.description,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        createdAt: createdAt,
        assigneeId: identical(assigneeId, _unset) ? this.assigneeId : assigneeId as String?,
        notes: notes ?? this.notes,
      );
}

class MaintenancePlan {
  const MaintenancePlan({
    required this.id,
    required this.clientId,
    required this.name,
    required this.monthlyFee,
    required this.nextReview,
    this.includes = const [],
    this.active = true,
  });

  final String id;
  final String clientId;
  final String name;
  final double monthlyFee;
  final DateTime nextReview;
  final List<String> includes;
  final bool active;

  MaintenancePlan copyWith({bool? active, DateTime? nextReview}) => MaintenancePlan(
        id: id,
        clientId: clientId,
        name: name,
        monthlyFee: monthlyFee,
        nextReview: nextReview ?? this.nextReview,
        includes: includes,
        active: active ?? this.active,
      );
}

const _unset = Object();

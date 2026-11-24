import 'common.dart';
import 'enums.dart';

class FollowUp {
  const FollowUp({
    required this.id,
    required this.at,
    required this.type,
    this.note = '',
    this.done = false,
  });

  final String id;
  final DateTime at;
  final FollowUpType type;
  final String note;
  final bool done;

  FollowUp copyWith({bool? done}) =>
      FollowUp(id: id, at: at, type: type, note: note, done: done ?? this.done);
}

class Lead {
  const Lead({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.source,
    required this.status,
    required this.createdAt,
    this.estimatedValue = 0,
    this.service = ServiceInterest.other,
    this.budget,
    this.ownerId,
    this.interest = '',
    this.website = '',
    this.location = '',
    this.followUps = const [],
    this.notes = const [],
    this.history = const [],
  });

  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final LeadSource source;
  final LeadStatus status;
  final DateTime createdAt;
  final double estimatedValue;
  final ServiceInterest service;

  /// Budget band the lead gave, if any.
  final BudgetBand? budget;

  /// Team member responsible for this lead; null means unassigned.
  final String? ownerId;

  /// What the lead is interested in, in their own words (the enquiry message).
  final String interest;

  /// The business's own website, when it has one. Empty means none was found.
  final String website;

  /// Area or address, mostly for businesses found by searching a map.
  final String location;
  final List<FollowUp> followUps;
  final List<Note> notes;
  final List<ActivityEntry> history;

  /// The company when there is one, otherwise the lead's own name (a shop is both).
  String get displayCompany => company.isNotEmpty ? company : name;

  /// "Name · Company", or just the name when they are the same or there is no company.
  String get titleLine => company.isEmpty || company == name ? name : '$name · $company';

  FollowUp? get nextFollowUp {
    final pending = followUps.where((f) => !f.done).toList()..sort((a, b) => a.at.compareTo(b.at));
    return pending.isEmpty ? null : pending.first;
  }

  Lead copyWith({
    String? name,
    String? company,
    String? email,
    String? phone,
    LeadSource? source,
    LeadStatus? status,
    double? estimatedValue,
    ServiceInterest? service,
    Object? budget = _unset,
    Object? ownerId = _unset,
    String? interest,
    String? website,
    String? location,
    List<FollowUp>? followUps,
    List<Note>? notes,
    List<ActivityEntry>? history,
  }) =>
      Lead(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        source: source ?? this.source,
        status: status ?? this.status,
        createdAt: createdAt,
        estimatedValue: estimatedValue ?? this.estimatedValue,
        service: service ?? this.service,
        budget: identical(budget, _unset) ? this.budget : budget as BudgetBand?,
        ownerId: identical(ownerId, _unset) ? this.ownerId : ownerId as String?,
        interest: interest ?? this.interest,
        website: website ?? this.website,
        location: location ?? this.location,
        followUps: followUps ?? this.followUps,
        notes: notes ?? this.notes,
        history: history ?? this.history,
      );
}

const _unset = Object();

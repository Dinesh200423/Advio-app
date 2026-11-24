import 'common.dart';
import 'enums.dart';

class Client {
  const Client({
    required this.id,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.createdAt,
    this.address = '',
    this.website = '',
    this.status = ClientStatus.active,
    this.notes = const [],
    this.history = const [],
  });

  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String address;
  final String website;
  final ClientStatus status;
  final DateTime createdAt;
  final List<Note> notes;
  final List<ActivityEntry> history;

  /// Display name: company when present, otherwise the contact name.
  String get displayName => company.isNotEmpty ? company : name;

  Client copyWith({
    String? name,
    String? company,
    String? email,
    String? phone,
    String? address,
    String? website,
    ClientStatus? status,
    List<Note>? notes,
    List<ActivityEntry>? history,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        website: website ?? this.website,
        status: status ?? this.status,
        createdAt: createdAt,
        notes: notes ?? this.notes,
        history: history ?? this.history,
      );
}

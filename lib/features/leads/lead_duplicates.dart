import '../../data/models/client.dart';
import '../../data/models/lead.dart';

/// Digits only, and for long numbers just the last ten, so "+91 98765 43210", "098765-43210" and
/// "9876543210" all compare equal. Returns '' for anything too short to identify a number.
String normalizePhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.length < 7) return '';
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}

/// "https://www.Example.com/contact" and "example.com" both become "example.com".
String normalizeSite(String url) {
  var s = url.trim().toLowerCase();
  s = s.replaceFirst(RegExp(r'^[a-z]+://'), '').replaceFirst(RegExp(r'^www\.'), '');
  final end = s.indexOf(RegExp(r'[/?#]'));
  if (end >= 0) s = s.substring(0, end);
  return s;
}

String _letters(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// What an existing lead or client matched on, shown to the person adding the new one.
class DuplicateMatch {
  const DuplicateMatch({required this.name, required this.reason, this.leadId, this.isClient = false});
  final String name;
  final String reason;
  final String? leadId;
  final bool isClient;
}

/// Looks for a lead or client that is probably the same business: same phone number, same website,
/// or same name in the same area. Leads come first, then clients.
DuplicateMatch? findDuplicate({
  required String name,
  required String phone,
  required String website,
  required String location,
  required Iterable<Lead> leads,
  required Iterable<Client> clients,
}) {
  final p = normalizePhone(phone);
  final w = normalizeSite(website);
  final n = _letters(name);
  final area = _letters(location);

  String? why({required String otherName, required String otherPhone, required String otherSite, String? otherArea}) {
    if (p.isNotEmpty && normalizePhone(otherPhone) == p) return 'same phone number';
    if (w.isNotEmpty && normalizeSite(otherSite) == w) return 'same website';
    if (n.isNotEmpty && _letters(otherName) == n && area.isNotEmpty && otherArea != null && _letters(otherArea) == area) {
      return 'same name in the same area';
    }
    return null;
  }

  for (final l in leads) {
    final r = why(otherName: l.name, otherPhone: l.phone, otherSite: l.website, otherArea: l.location);
    if (r != null) return DuplicateMatch(name: l.name, reason: r, leadId: l.id);
  }
  for (final c in clients) {
    final r = why(otherName: c.displayName, otherPhone: c.phone, otherSite: c.website, otherArea: c.address);
    if (r != null) return DuplicateMatch(name: c.displayName, reason: r, isClient: true);
  }
  return null;
}

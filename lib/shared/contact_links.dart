import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a link in another app (dialer, WhatsApp, mail, browser). Returns false when nothing could handle it.
/// A provider so tests can replace it, since a test has no phone to call.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>((ref) {
  return (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  };
});

String _digits(String s) => s.replaceAll(RegExp(r'[^\d]'), '');

/// A number the dialer understands, or null when there is nothing dialable.
Uri? telLink(String phone) {
  final trimmed = phone.trim();
  final digits = _digits(trimmed);
  if (digits.length < 7) return null;
  return Uri(scheme: 'tel', path: trimmed.startsWith('+') ? '+$digits' : digits);
}

/// A WhatsApp chat link. WhatsApp needs the country code, but phone numbers are usually saved the way
/// people dial them in India (10 digits, sometimes with a leading 0), so those get +91.
Uri? whatsappLink(String phone, {String defaultCountryCode = '91'}) {
  var digits = _digits(phone);
  if (digits.length < 7) return null;
  if (phone.trim().startsWith('+')) {
    // Already international.
  } else if (digits.startsWith('0')) {
    digits = '$defaultCountryCode${digits.replaceFirst(RegExp(r'^0+'), '')}';
  } else if (digits.length == 10) {
    digits = '$defaultCountryCode$digits';
  }
  return Uri.https('wa.me', '/$digits');
}

Uri? mailLink(String email) {
  final e = email.trim();
  if (!e.contains('@')) return null;
  return Uri(scheme: 'mailto', path: e);
}

/// Websites are often saved without a scheme ("example.com").
Uri? webLink(String url) {
  final u = url.trim();
  if (u.isEmpty) return null;
  final uri = Uri.tryParse(u.contains('://') ? u : 'https://$u');
  return uri != null && uri.host.contains('.') ? uri : null;
}

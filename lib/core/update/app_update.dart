import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../observability/app_log.dart';

/// Where new versions are published. Each release is tagged like "v1.2.0" and carries the APK as a file.
/// The repository has to be readable without signing in, since the app has no password to give GitHub.
abstract final class UpdateConfig {
  static const releasesRepo = 'Dinesh200423/Advio-app';
}

class UpdateInfo {
  const UpdateInfo({required this.version, required this.apkUrl, this.notes = ''});
  final String version;
  final String apkUrl;
  final String notes;
}

/// "v1.2.3", "1.2.3+4" and "1.2" all reduce to their numbers; anything unreadable counts as 0.
List<int> _parts(String version) {
  final core = version.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[+-]')).first;
  final nums = core.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (nums.length < 3) {
    nums.add(0);
  }
  return nums;
}

/// True when [candidate] is a higher version than [installed].
bool isNewerVersion(String candidate, String installed) {
  final a = _parts(candidate);
  final b = _parts(installed);
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Reads one GitHub "latest release" response. Returns null for drafts, pre-releases and releases without an APK.
UpdateInfo? parseRelease(Map<String, dynamic> json) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  if (tag is! String || tag.isEmpty) return null;
  final assets = json['assets'];
  if (assets is! List) return null;
  for (final a in assets) {
    if (a is Map && (a['name'] as String?)?.toLowerCase().endsWith('.apk') == true && a['browser_download_url'] is String) {
      return UpdateInfo(version: tag.replaceFirst(RegExp(r'^[vV]'), ''), apkUrl: a['browser_download_url'] as String, notes: (json['body'] as String? ?? '').trim());
    }
  }
  return null;
}

/// Fetches the latest published release, or null if none can be read. Never throws: an update check
/// that fails (offline, rate limited, repository private) must not bother anyone.
typedef UpdateChecker = Future<UpdateInfo?> Function();

final updateCheckerProvider = Provider<UpdateChecker>((ref) {
  return () async {
    // Updates are installed from an APK, which only means something on Android.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final response = await http
          .get(Uri.https('api.github.com', '/repos/${UpdateConfig.releasesRepo}/releases/latest'), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        AppLog.debug('Update check skipped', data: {'status': response.statusCode});
        return null;
      }
      return parseRelease(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (error) {
      AppLog.debug('Update check failed', data: {'error': error.runtimeType.toString()});
      return null;
    }
  };
});

/// The version this phone is running, as written in pubspec.yaml ("1.0.0").
final installedVersionProvider = FutureProvider<String>((ref) async => (await PackageInfo.fromPlatform()).version);

/// A newer release than the one installed, or null.
final availableUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final latest = await ref.read(updateCheckerProvider)();
  if (latest == null) return null;
  final installed = await ref.watch(installedVersionProvider.future);
  return isNewerVersion(latest.version, installed) ? latest : null;
});

/// Remembers that this session has already been asked, so the prompt appears once per launch.
class UpdatePromptedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void markShown() => state = true;
}

final updatePromptedProvider = NotifierProvider<UpdatePromptedNotifier, bool>(UpdatePromptedNotifier.new);

import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/core/update/app_update.dart';
import 'package:freelance_os/shared/contact_links.dart';

import 'helpers.dart';

const newer = UpdateInfo(version: '1.2.0', apkUrl: 'https://example.com/advio.apk', notes: 'Push alerts for new leads.');

void main() {
  group('versions', () {
    test('compares numbers, not text', () {
      expect(isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.0'), isTrue, reason: '10 is more than 9');
      expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
      expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(isNewerVersion('1.0.0', '1.0.1'), isFalse);
    });

    test('ignores a leading v and the build number', () {
      expect(isNewerVersion('v1.1.0', '1.0.0+7'), isTrue);
      expect(isNewerVersion('v1.0.0', '1.0.0+7'), isFalse);
      expect(isNewerVersion('1.1', '1.0.5'), isTrue);
    });

    test('anything unreadable is treated as zero, never as an update', () {
      expect(isNewerVersion('latest', '1.0.0'), isFalse);
      expect(isNewerVersion('', '1.0.0'), isFalse);
    });
  });

  group('release parsing', () {
    Map<String, dynamic> release({bool draft = false, bool pre = false, List<Map<String, dynamic>>? assets, String tag = 'v1.2.0'}) => {
          'tag_name': tag,
          'draft': draft,
          'prerelease': pre,
          'body': '  Push alerts.  ',
          'assets': assets ??
              [
                {'name': 'notes.txt', 'browser_download_url': 'https://example.com/notes.txt'},
                {'name': 'ADVIO-1.2.0.APK', 'browser_download_url': 'https://example.com/advio.apk'},
              ],
        };

    test('picks the APK, strips the v, and trims the notes', () {
      final info = parseRelease(release())!;
      expect(info.version, '1.2.0');
      expect(info.apkUrl, 'https://example.com/advio.apk');
      expect(info.notes, 'Push alerts.');
    });

    test('ignores drafts, pre-releases, releases without an APK, and nonsense', () {
      expect(parseRelease(release(draft: true)), isNull);
      expect(parseRelease(release(pre: true)), isNull);
      expect(parseRelease(release(assets: [])), isNull);
      expect(parseRelease({'message': 'Not Found'}), isNull);
      expect(parseRelease(release(tag: '')), isNull);
    });
  });

  group('the prompt', () {
    testWidgets('appears once when a newer version exists, and Update opens the download', (tester) async {
      final opened = <Uri>[];
      await pumpApp(tester, updateCheck: () async => newer, overrides: [
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(find.textContaining('ADVIO 1.2.0 is ready. You are on 1.0.0.'), findsOneWidget);
      expect(find.textContaining('Push alerts for new leads.'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), 'https://example.com/advio.apk');
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('"Later" closes it and does not nag again in the same session', (tester) async {
      await pumpApp(tester, updateCheck: () async => newer);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
      await goTo(tester, '/leads');
      await goTo(tester, '/home');
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('does not appear when already up to date, or when the check finds nothing', (tester) async {
      await pumpApp(tester, updateCheck: () async => const UpdateInfo(version: '1.0.0', apkUrl: 'x'));
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('"Check for updates" in About reports the result', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/settings/about');
      expect(find.text('1.0.0'), findsOneWidget);
      await tester.tap(find.text('Check for updates'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Could not check for updates right now.'), findsOneWidget);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/mock/mock_business.dart';
import 'package:freelance_os/data/mock/mock_crm.dart';
import 'package:freelance_os/data/models/app_settings.dart';
import 'package:freelance_os/data/models/common.dart';
import 'package:freelance_os/shared/pdf/document_pdf.dart';

import 'helpers.dart';

String latin(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);

void main() {
  const settings = AppSettings(businessName: 'ADVIO', taxId: '33ABCDE1234F1Z5');

  DocumentData invoiceData() {
    final invoice = MockBusiness.invoices().firstWhere((i) => i.payments.isNotEmpty);
    final client = MockCrm.clients().firstWhere((c) => c.id == invoice.clientId);
    return DocumentData.invoice(invoice, client: client, settings: settings);
  }

  group('the PDF file', () {
    test('is a real PDF carrying the document number, and a file name that is safe everywhere', () async {
      final data = invoiceData();
      final bytes = await buildDocumentPdf(data);
      expect(latin(bytes).startsWith('%PDF-'), isTrue);
      expect(bytes.length, greaterThan(3000), reason: 'embeds the Inter font');
      expect(latin(bytes), contains('INVOICE ${data.number}'), reason: 'document title');
      expect(data.fileName, matches(RegExp(r'^INVOICE-[A-Za-z0-9._-]+\.pdf$')));
    });

    test('a quotation carries its project title, validity date and terms', () async {
      final q = MockBusiness.quotations().firstWhere((q) => q.terms.isNotEmpty);
      final data = DocumentData.quotation(q, client: MockCrm.clients().first, settings: settings);
      expect(data.kind, 'QUOTATION');
      expect(data.secondDateLabel, 'Valid until');
      expect(data.title, q.title);
      expect((await buildDocumentPdf(data)).length, greaterThan(3000));
    });

    test('a long document runs onto more pages instead of being cut off', () async {
      final base = invoiceData();
      DocumentData withItems(int n) => DocumentData(
            kind: base.kind,
            number: base.number,
            businessName: base.businessName,
            businessAddress: base.businessAddress,
            client: base.client,
            items: [for (var i = 0; i < n; i++) LineItem(id: 'i$i', description: 'Work item number $i', quantity: 2, unitPrice: 1500)],
            discountPercent: 5,
            taxPercent: 18,
            issueDate: base.issueDate,
            secondDateLabel: base.secondDateLabel,
            secondDate: base.secondDate,
            currency: 'INR',
          );
      int pages(Uint8List b) => RegExp(r'/Type\s*/Page(?![s\w])').allMatches(latin(b)).length;
      expect(pages(await buildDocumentPdf(withItems(3))), 1);
      expect(pages(await buildDocumentPdf(withItems(90))), greaterThan(1));
    });

    test('paid invoices list what was paid and what is still due', () {
      final data = invoiceData();
      expect(data.extraRows.map((r) => r.label), ['Paid', 'Balance due']);
      expect(data.extraRows.last.strong, isTrue);
    });
  });

  group('the Download PDF button', () {
    Future<List<({Uint8List bytes, String name})>> openPreview(WidgetTester tester, String route, {Object? failWith}) async {
      final shared = <({Uint8List bytes, String name})>[];
      await pumpApp(tester, size: const Size(390, 1800), overrides: [
        pdfSharerProvider.overrideWithValue((bytes, name) async {
          if (failWith != null) throw failWith;
          shared.add((bytes: bytes, name: name));
        }),
      ]);
      await goTo(tester, route);
      return shared;
    }

    testWidgets('an invoice: builds the PDF and hands it over to be saved or shared', (tester) async {
      final invoice = MockBusiness.invoices().first;
      final shared = await openPreview(tester, '/invoices/${invoice.id}/preview');
      await tester.runAsync(() async {
        await tester.tap(find.text('Download PDF'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();

      expect(shared, hasLength(1));
      expect(latin(shared.single.bytes).startsWith('%PDF-'), isTrue);
      expect(shared.single.name, 'INVOICE-${invoice.number}.pdf');
      expectNoFlutterErrors(tester);
    });

    testWidgets('a quotation: same', (tester) async {
      final quotation = MockBusiness.quotations().first;
      final shared = await openPreview(tester, '/quotations/${quotation.id}/preview');
      await tester.runAsync(() async {
        await tester.tap(find.text('Download PDF'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump();

      expect(shared.single.name, 'QUOTATION-${quotation.number}.pdf');
      expect(latin(shared.single.bytes).startsWith('%PDF-'), isTrue);
    });

    testWidgets('if handing it over fails, the person is told', (tester) async {
      final invoice = MockBusiness.invoices().first;
      await openPreview(tester, '/invoices/${invoice.id}/preview', failWith: StateError('no share target'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Download PDF'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Could not create the PDF. Please try again.'), findsOneWidget);
    });

    testWidgets('the detail pages point to it', (tester) async {
      final invoice = MockBusiness.invoices().first;
      await pumpApp(tester, size: const Size(390, 1800));
      await goTo(tester, '/invoices/${invoice.id}');
      expect(find.text('Preview & PDF'), findsWidgets);
    });
  });
}

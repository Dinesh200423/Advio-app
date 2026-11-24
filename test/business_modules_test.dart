import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/features/expenses/expense_providers.dart';
import 'package:freelance_os/features/invoices/invoice_providers.dart';
import 'package:freelance_os/features/quotations/quotation_providers.dart';

import 'helpers.dart';

const tall = Size(390, 2200);

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

Future<void> submit(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pump(const Duration(milliseconds: 700));
  await settle(tester);
}

Future<void> chooseFromDropdown(WidgetTester tester, Finder dropdown, String option) async {
  await tester.tap(dropdown);
  await settle(tester);
  await tester.tap(find.text(option).last);
  await settle(tester);
}

void main() {
  group('Finance & invoices', () {
    testWidgets('finance tab shows summary, cash flow and what to collect', (tester) async {
      await pumpApp(tester, size: tall);
      await tester.tap(find.text('Finance').last);
      await settle(tester);
      expect(find.text('Cash flow'), findsOneWidget);
      expect(find.text('To collect'), findsOneWidget);
      expect(find.text('Recent payments'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });

    testWidgets('invoice list filters by status from the query string', (tester) async {
      await pumpApp(tester, size: tall);
      await goTo(tester, '/finance');
      await pushTo(tester, '/invoices?status=overdue');
      expect(find.text('GreenLeaf Organics'), findsOneWidget);
      expect(find.text('Zenith Fintech'), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('partial payment leaves a balance; overpaying is rejected', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/finance');
      final before = container.read(invoiceProvider('inv18'))!;
      expect(before.displayStatus, InvoiceStatus.sent);

      await pushTo(tester, '/invoices/inv18/payment');
      await tester.enterText(find.byType(TextFormField).first, '999999');
      await tester.tap(find.widgetWithText(FilledButton, 'Save payment'));
      await tester.pump();
      expect(find.text('More than the balance due'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, '20000');
      await tester.pump();
      expect(find.textContaining('Partial payment'), findsOneWidget);
      await submit(tester, 'Save payment');

      final after = container.read(invoiceProvider('inv18'))!;
      expect(after.paid, 20000);
      expect(after.displayStatus, InvoiceStatus.partiallyPaid);
      expect(after.balance, before.total - 20000);
      expectNoFlutterErrors(tester);
    });

    testWidgets('paying the full balance marks the invoice paid and updates revenue', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/finance');
      final revenueBefore = container.read(monthlyRevenueProvider);
      final inv = container.read(invoiceProvider('inv16'))!;

      await pushTo(tester, '/invoices/inv16/payment');
      await submit(tester, 'Save payment'); // amount pre-filled with the balance
      expect(container.read(invoiceProvider('inv16'))!.displayStatus, InvoiceStatus.paid);
      expect(container.read(monthlyRevenueProvider), revenueBefore + inv.total);
    });

    testWidgets('create an invoice with a line item and send it', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/finance');
      final before = container.read(invoicesProvider).length;

      await pushTo(tester, '/invoices/new');
      await tester.tap(find.widgetWithText(FilledButton, 'Create & send'));
      await tester.pump();
      expect(find.text('Please choose a client'), findsOneWidget);

      await chooseFromDropdown(tester, find.byType(DropdownButtonFormField<String>).first, 'Urban Nest Interiors');
      await tester.enterText(find.byType(TextFormField).at(0), 'Homepage build');
      await tester.enterText(find.byType(TextFormField).at(2), '10000'); // unit price (qty defaults to 1)
      await tester.pump();
      await submit(tester, 'Create & send');

      final list = container.read(invoicesProvider);
      expect(list.length, before + 1);
      final created = list.first;
      expect(created.status, InvoiceStatus.sent);
      expect(created.items.single.description, 'Homepage build');
      expect(created.total, 11800); // 10,000 + 18% default tax
      expectNoFlutterErrors(tester);
    });

    testWidgets('draft invoice can be sent from its detail page', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await goTo(tester, '/finance');
      await pushTo(tester, '/invoices/inv19');
      await tester.tap(find.text('Send invoice'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await settle(tester);
      expect(container.read(invoiceProvider('inv19'))!.status, InvoiceStatus.sent);
    });

    testWidgets('preview screens render without layout errors', (tester) async {
      await pumpApp(tester);
      await goTo(tester, '/finance');
      await pushTo(tester, '/invoices/inv14/preview');
      expect(find.text('INVOICE'), findsOneWidget);
      expect(find.text('Balance due'), findsOneWidget);
      await pushTo(tester, '/quotations/q6/preview');
      expect(find.text('QUOTATION'), findsOneWidget);
      expectNoFlutterErrors(tester);
    });
  });

  group('Quotations', () {
    testWidgets('list shows overview, filters by status', (tester) async {
      await pumpApp(tester, size: tall);
      await pushTo(tester, '/quotations');
      expect(find.text('Win rate'), findsOneWidget);
      await tester.tap(find.text('Draft  1'));
      await settle(tester);
      expect(find.text('Analytics integration add-on'), findsOneWidget);
      expect(find.text('Learning management portal'), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('draft → sent after confirmation', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/quotations/q4');
      await tester.tap(find.text('Send to client'));
      await settle(tester);
      expect(find.text('Send quotation?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Send'));
      await settle(tester);
      expect(container.read(quotationProvider('q4'))!.status, QuotationStatus.sent);
    });

    testWidgets('accepting a quotation lets you turn it into an invoice', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/quotations/q6');
      await tester.tap(find.text('Mark accepted'));
      await settle(tester);
      expect(container.read(quotationProvider('q6'))!.status, QuotationStatus.accepted);

      final before = container.read(invoicesProvider).length;
      await tester.tap(find.text('Create invoice'));
      await settle(tester);
      final invoices = container.read(invoicesProvider);
      expect(invoices.length, before + 1);
      expect(invoices.first.clientId, 'c4');
      expect(invoices.first.status, InvoiceStatus.draft);
      expect(invoices.first.total, container.read(quotationProvider('q6'))!.totals.total);
    });

    testWidgets('create quotation: totals include discount and tax', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/quotations');
      final before = container.read(quotationsProvider).length;
      await pushTo(tester, '/quotations/new');

      await chooseFromDropdown(tester, find.byType(DropdownButtonFormField<String>).first, 'Bloom Wellness Studio');
      await tester.enterText(find.byType(TextFormField).at(0), 'Retainer package');
      await tester.enterText(find.byType(TextFormField).at(1), 'Design hours');
      await tester.enterText(find.byType(TextFormField).at(2), '4'); // qty
      await tester.enterText(find.byType(TextFormField).at(3), '5000'); // price
      await tester.enterText(find.byType(TextFormField).at(4), '10'); // discount %
      await tester.pump();
      await submit(tester, 'Save quotation');

      final list = container.read(quotationsProvider);
      expect(list.length, before + 1);
      final q = list.first;
      // 4 × 5000 = 20000, −10% = 18000, +18% tax = 21240
      expect(q.totals.total, 21240);
      expect(q.status, QuotationStatus.draft);
      expect(q.number, 'QT-${DateTime.now().year}-008');
      expectNoFlutterErrors(tester);
    });
  });

  group('Expenses', () {
    testWidgets('overview shows totals and charts; range filter changes the data', (tester) async {
      await pumpApp(tester, size: tall);
      await pushTo(tester, '/expenses');
      expect(find.text('Total spent'), findsOneWidget);
      expect(find.text('By category'), findsOneWidget);
      expect(find.text('Monthly expenses'), findsOneWidget);
      final countFinder = find.textContaining(RegExp(r'^\d+ expenses$'));
      final thisMonth = tester.widget<Text>(countFinder).data;
      await tester.tap(find.text('3 months'));
      await settle(tester);
      expect(tester.widget<Text>(countFinder).data, isNot(thisMonth));
      expectNoFlutterErrors(tester);
    });

    testWidgets('add an expense with a receipt', (tester) async {
      final container = await pumpApp(tester, size: tall);
      await pushTo(tester, '/expenses');
      final before = container.read(expensesProvider).length;
      await tester.tap(find.text('Add expense').first);
      await settle(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
      await tester.pump();
      expect(find.text('Title is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Domain renewal');
      await tester.enterText(find.byType(TextFormField).at(1), '1200');
      await tester.tap(find.text('Attach receipt'));
      await settle(tester);
      await tester.tap(find.text('invoice-scan.pdf'));
      await settle(tester);
      await submit(tester, 'Add expense');

      final list = container.read(expensesProvider);
      expect(list.length, before + 1);
      expect(list.first.amount, 1200);
      expect(list.first.receiptName, 'invoice-scan.pdf');
      expectNoFlutterErrors(tester);
    });
  });
}

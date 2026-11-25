import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/client.dart';
import '../../data/models/common.dart';
import '../../data/models/invoice.dart';
import '../../data/models/enums.dart';
import '../../data/models/quotation.dart';

/// Everything printed on a quotation or an invoice.
class DocumentData {
  const DocumentData({
    required this.kind,
    required this.number,
    required this.businessName,
    required this.businessAddress,
    required this.items,
    required this.discountPercent,
    required this.taxPercent,
    required this.issueDate,
    required this.secondDateLabel,
    required this.secondDate,
    required this.currency,
    this.taxId = '',
    this.contactLine = '',
    this.client,
    this.title = '',
    this.notes = '',
    this.terms = '',
    this.statusLabel,
    this.extraRows = const [],
  });

  final String kind; // "QUOTATION" / "INVOICE"
  final String number;
  final String businessName;
  final String businessAddress;
  final String taxId;

  /// Phone, email and website of the business, shown under its address.
  final String contactLine;
  final Client? client;
  final String title;
  final List<LineItem> items;
  final double discountPercent;
  final double taxPercent;
  final DateTime issueDate;
  final String secondDateLabel;
  final DateTime secondDate;
  final String notes;
  final String terms;
  final String? statusLabel;
  final String currency;

  /// Rows under the total, such as "Paid" and "Balance due".
  final List<({String label, String value, bool strong})> extraRows;

  factory DocumentData.quotation(Quotation q, {required Client? client, required AppSettings settings}) => DocumentData(
        kind: 'QUOTATION',
        number: q.number,
        businessName: settings.businessName,
        businessAddress: settings.businessAddress,
        taxId: settings.taxId,
        contactLine: _contactLine(settings),
        client: client,
        title: q.title,
        items: q.items,
        discountPercent: q.discountPercent,
        taxPercent: q.taxPercent,
        issueDate: q.issueDate,
        secondDateLabel: 'Valid until',
        secondDate: q.validUntil,
        notes: q.notes,
        terms: q.terms,
        statusLabel: q.displayStatus.label,
        currency: settings.currency,
      );

  factory DocumentData.invoice(Invoice i, {required Client? client, required AppSettings settings}) {
    final showPaid = i.paid > 0;
    return DocumentData(
      kind: 'INVOICE',
      number: i.number,
      businessName: settings.businessName,
      businessAddress: settings.businessAddress,
      taxId: settings.taxId,
      contactLine: _contactLine(settings),
      client: client,
      items: i.items,
      discountPercent: i.discountPercent,
      taxPercent: i.taxPercent,
      issueDate: i.issueDate,
      secondDateLabel: 'Due date',
      secondDate: i.dueDate,
      notes: i.notes,
      statusLabel: i.displayStatus.label,
      currency: settings.currency,
      extraRows: [
        if (showPaid) (label: 'Paid', value: '- ${formatMoney(i.paid, settings.currency)}', strong: false),
        if (showPaid && i.displayStatus != InvoiceStatus.voided) (label: 'Balance due', value: formatMoney(i.balance, settings.currency), strong: true),
      ],
    );
  }

  /// A file name that is safe on every system: "INVOICE-INV-2026-004.pdf".
  String get fileName => '$kind-$number.pdf'.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');

  static String _contactLine(AppSettings s) => [s.phone, s.email, s.website].where((v) => v.trim().isNotEmpty).join('  ·  ');
}

const _ink = PdfColor.fromInt(0xFF1C1C1C);
const _muted = PdfColor.fromInt(0xFF6B6B6B);
const _line = PdfColor.fromInt(0xFFDADADA);
const _band = PdfColor.fromInt(0xFFF1F1F1);
const _accent = PdfColor.fromInt(0xFFD4F53C);

String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Builds the PDF. The bundled Inter font is used because the standard PDF fonts cannot draw the rupee sign.
Future<Uint8List> buildDocumentPdf(DocumentData d) async {
  final regular = pw.Font.ttf(await rootBundle.load('google_fonts/Inter-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('google_fonts/Inter-SemiBold.ttf'));
  String money(num v) => formatMoney(v, d.currency);
  final totals = DocTotals.compute(d.items, discountPercent: d.discountPercent, taxPercent: d.taxPercent);

  pw.TextStyle text({double size = 10, bool strong = false, PdfColor color = _ink}) =>
      pw.TextStyle(fontSize: size, fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal, color: color);

  pw.Widget totalRow(String label, String value, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Text(label, style: text(size: strong ? 11 : 10, strong: strong, color: strong ? _ink : _muted)),
          pw.Spacer(),
          pw.Text(value, style: text(size: strong ? 12 : 10, strong: true)),
        ]),
      );

  final client = d.client;
  final doc = pw.Document(title: '${d.kind} ${d.number}', author: d.businessName);
  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 44),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(children: [
          pw.Text(d.businessName, style: text(size: 8, color: _muted)),
          pw.Spacer(),
          pw.Text('${d.kind} ${d.number}  ·  Page ${context.pageNumber} of ${context.pagesCount}', style: text(size: 8, color: _muted)),
        ]),
      ),
      build: (context) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(d.businessName, style: text(size: 18, strong: true)),
              pw.SizedBox(height: 4),
              if (d.businessAddress.isNotEmpty) pw.Text(d.businessAddress, style: text(size: 9, color: _muted)),
              if (d.taxId.isNotEmpty) pw.Text('GSTIN: ${d.taxId}', style: text(size: 9, color: _muted)),
              if (d.contactLine.isNotEmpty) pw.Text(d.contactLine, style: text(size: 9, color: _muted)),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(d.kind, style: text(size: 20, strong: true)),
            pw.Text(d.number, style: text(size: 11, strong: true)),
            if (d.statusLabel != null)
              pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(d.statusLabel!.toUpperCase(), style: text(size: 9, strong: true, color: _muted))),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Container(height: 3, width: 60, color: _accent),
        pw.SizedBox(height: 18),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BILLED TO', style: text(size: 8, color: _muted)),
              pw.SizedBox(height: 4),
              pw.Text(client?.displayName ?? '-', style: text(size: 11, strong: true)),
              if (client != null && client.company.isNotEmpty) pw.Text(client.name, style: text(size: 9, color: _muted)),
              if (client != null && client.address.isNotEmpty) pw.Text(client.address, style: text(size: 9, color: _muted)),
              if (client != null && client.email.isNotEmpty) pw.Text(client.email, style: text(size: 9, color: _muted)),
              if (client != null && client.phone.isNotEmpty) pw.Text(client.phone, style: text(size: 9, color: _muted)),
            ]),
          ),
          pw.SizedBox(width: 16),
          pw.SizedBox(
            width: 170,
            child: pw.Column(children: [
              pw.Row(children: [pw.Text('Issued', style: text(size: 9, color: _muted)), pw.Spacer(), pw.Text(Fmt.date(d.issueDate), style: text(size: 9, strong: true))]),
              pw.SizedBox(height: 4),
              pw.Row(children: [pw.Text(d.secondDateLabel, style: text(size: 9, color: _muted)), pw.Spacer(), pw.Text(Fmt.date(d.secondDate), style: text(size: 9, strong: true))]),
            ]),
          ),
        ]),
        if (d.title.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Project', style: text(size: 8, color: _muted)),
          pw.Text(d.title, style: text(size: 11, strong: true)),
        ],
        pw.SizedBox(height: 18),
        pw.Container(
          color: _band,
          padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          child: pw.Row(children: [
            pw.Expanded(flex: 6, child: pw.Text('Description', style: text(size: 9, strong: true))),
            pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: text(size: 9, strong: true))),
            pw.Expanded(flex: 2, child: pw.Text('Rate', textAlign: pw.TextAlign.right, style: text(size: 9, strong: true))),
            pw.Expanded(flex: 2, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: text(size: 9, strong: true))),
          ]),
        ),
        for (final item in d.items)
          pw.Container(
            decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: 0.6))),
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(flex: 6, child: pw.Text(item.description.isEmpty ? 'Untitled item' : item.description, style: text(size: 10))),
              pw.Expanded(flex: 1, child: pw.Text(_qty(item.quantity), textAlign: pw.TextAlign.center, style: text(size: 10))),
              pw.Expanded(flex: 2, child: pw.Text(money(item.unitPrice), textAlign: pw.TextAlign.right, style: text(size: 10))),
              pw.Expanded(flex: 2, child: pw.Text(money(item.total), textAlign: pw.TextAlign.right, style: text(size: 10, strong: true))),
            ]),
          ),
        pw.SizedBox(height: 14),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 230,
            child: pw.Column(children: [
              totalRow('Subtotal', money(totals.subtotal)),
              if (d.discountPercent > 0) totalRow('Discount (${_pct(d.discountPercent)}%)', '- ${money(totals.discount)}'),
              if (d.taxPercent > 0) totalRow('Tax (${_pct(d.taxPercent)}%)', money(totals.tax)),
              pw.Divider(color: _line, height: 14),
              totalRow('Total', money(totals.total), strong: true),
              for (final row in d.extraRows) totalRow(row.label, row.value, strong: row.strong),
            ]),
          ),
        ),
        if (d.notes.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Text('Notes', style: text(size: 10, strong: true)),
          pw.SizedBox(height: 3),
          pw.Text(d.notes, style: text(size: 9.5)),
        ],
        if (d.terms.isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Terms', style: text(size: 10, strong: true)),
          pw.SizedBox(height: 3),
          pw.Text(d.terms, style: text(size: 9, color: _muted)),
        ],
      ],
    ),
  );
  return doc.save();
}

/// Hands the finished PDF to the phone (its share sheet, where it can be saved or sent) or the browser (a download).
/// A provider so tests can replace it.
typedef PdfSharer = Future<void> Function(Uint8List bytes, String fileName);

final pdfSharerProvider = Provider<PdfSharer>((ref) => (bytes, fileName) => Printing.sharePdf(bytes: bytes, filename: fileName));

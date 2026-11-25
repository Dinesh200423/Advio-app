import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/observability/app_log.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/client.dart';
import '../../data/models/common.dart';
import '../../features/settings/settings_providers.dart';
import '../pdf/document_pdf.dart';

/// Subtotal / discount / tax / total block.
class TotalsSummary extends ConsumerWidget {
  const TotalsSummary({
    super.key,
    required this.items,
    required this.discountPercent,
    required this.taxPercent,
    this.extraRows = const [],
  });

  final List<LineItem> items;
  final double discountPercent;
  final double taxPercent;

  /// Additional label/value rows shown under the total (e.g. paid, balance due).
  final List<(String, String, {bool strong})> extraRows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = DocTotals.compute(items, discountPercent: discountPercent, taxPercent: taxPercent);
    Widget row(String l, String v, {bool strong = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(l, style: strong ? AppText.bodyStrong : AppText.body.copyWith(color: AppColors.muted)),
              const Spacer(),
              Text(v, style: (strong ? AppText.cardTitle : AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)).copyWith(color: color)),
            ],
          ),
        );

    return Column(
      children: [
        row('Subtotal', ref.money(t.subtotal)),
        if (discountPercent > 0) row('Discount (${_pct(discountPercent)}%)', '- ${ref.money(t.discount)}'),
        if (taxPercent > 0) row('Tax (${_pct(taxPercent)}%)', ref.money(t.tax)),
        const Divider(height: 20),
        row('Total', ref.money(t.total), strong: true),
        for (final r in extraRows) row(r.$1, r.$2, strong: r.strong),
      ],
    );
  }

  static String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// A document that reads like a printed quotation or invoice.
class DocumentPreview extends ConsumerWidget {
  const DocumentPreview({
    super.key,
    required this.kind,
    required this.number,
    required this.client,
    required this.items,
    required this.discountPercent,
    required this.taxPercent,
    required this.issueDate,
    required this.secondDateLabel,
    required this.secondDate,
    this.title,
    this.notes = '',
    this.terms = '',
    this.statusLabel,
    this.totalsExtra = const [],
  });

  final String kind; // "QUOTATION" / "INVOICE"
  final String number;
  final Client? client;
  final String? title;
  final List<LineItem> items;
  final double discountPercent;
  final double taxPercent;
  final DateTime issueDate;
  final String secondDateLabel;
  final DateTime secondDate;
  final String notes;
  final String terms;
  final String? statusLabel;
  final List<(String, String, {bool strong})> totalsExtra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);

    Widget meta(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 78, child: Text(label, style: AppText.caption)),
              Expanded(child: Text(value, style: AppText.labelStrong.copyWith(color: AppColors.ink))),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x141C1C1C), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.businessName, style: AppText.cardTitle),
                    const SizedBox(height: 4),
                    Text(s.businessAddress, style: AppText.caption),
                    if (s.taxId.isNotEmpty) Text('GSTIN: ${s.taxId}', style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(kind, style: AppText.sectionTitle.copyWith(color: AppColors.primary, letterSpacing: 1.2)),
                  Text(number, style: AppText.labelStrong),
                  if (statusLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(statusLabel!.toUpperCase(), style: AppText.caption.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILLED TO', style: AppText.caption.copyWith(letterSpacing: 0.8)),
                    const SizedBox(height: 6),
                    Text(client?.displayName ?? '—', style: AppText.bodyStrong),
                    if (client != null && client!.company.isNotEmpty) Text(client!.name, style: AppText.caption),
                    if (client != null && client!.address.isNotEmpty) Text(client!.address, style: AppText.caption),
                    if (client != null) Text(client!.email, style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: Column(
                  children: [meta('Issued', Fmt.date(issueDate)), meta(secondDateLabel, Fmt.date(secondDate))],
                ),
              ),
            ],
          ),
          if (title != null && title!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Project', style: AppText.caption),
            Text(title!, style: AppText.bodyStrong),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            color: const Color(0xFFF1F1F1),
            child: Row(
              children: [
                Expanded(flex: 5, child: Text('Description', style: AppText.caption.copyWith(fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.center, style: AppText.caption.copyWith(fontWeight: FontWeight.w600))),
                Expanded(flex: 3, child: Text('Amount', textAlign: TextAlign.end, style: AppText.caption.copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          for (final i in items)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(i.description.isEmpty ? 'Untitled item' : i.description, style: AppText.body.copyWith(fontSize: 13.5)),
                        Text('@ ${ref.money(i.unitPrice)}', style: AppText.caption),
                      ],
                    ),
                  ),
                  Expanded(flex: 1, child: Text(_qty(i.quantity), textAlign: TextAlign.center, style: AppText.body.copyWith(fontSize: 13.5))),
                  Expanded(flex: 3, child: Text(ref.money(i.total), textAlign: TextAlign.end, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500))),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: TotalsSummary(items: items, discountPercent: discountPercent, taxPercent: taxPercent, extraRows: totalsExtra),
            ),
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Notes', style: AppText.labelStrong),
            const SizedBox(height: 4),
            Text(notes, style: AppText.body.copyWith(fontSize: 13)),
          ],
          if (terms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Terms', style: AppText.labelStrong),
            const SizedBox(height: 4),
            Text(terms, style: AppText.caption.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }

  static String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Builds the PDF for [data] and hands it over to be saved or shared.
class DownloadPdfButton extends ConsumerStatefulWidget {
  const DownloadPdfButton({super.key, required this.data});
  final DocumentData data;

  @override
  ConsumerState<DownloadPdfButton> createState() => _DownloadPdfButtonState();
}

class _DownloadPdfButtonState extends ConsumerState<DownloadPdfButton> {
  bool _working = false;

  Future<void> _download() async {
    setState(() => _working = true);
    try {
      final bytes = await buildDocumentPdf(widget.data);
      await ref.read(pdfSharerProvider)(bytes, widget.data.fileName);
    } catch (error) {
      AppLog.warning('Could not create the PDF', error: error);
      if (mounted) AppSnack.error(context, 'Could not create the PDF. Please try again.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton.secondary(label: 'Download PDF', icon: Icons.download_rounded, onPressed: _working ? null : _download, loading: _working);
  }
}

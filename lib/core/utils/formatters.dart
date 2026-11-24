import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/settings/settings_providers.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
bool isToday(DateTime d) => isSameDay(d, DateTime.now());
bool isSameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

/// Whole days from today until [d] (negative when in the past).
int daysUntil(DateTime d) => dateOnly(d).difference(dateOnly(DateTime.now())).inDays;

abstract final class Fmt {
  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('d MMM').format(d);
  static String dateLong(DateTime d) => DateFormat('EEEE, d MMMM').format(d);
  static String dateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);
  static String time(DateTime d) => DateFormat('h:mm a').format(d);
  static String month(DateTime d) => DateFormat('MMM').format(d);
  static String monthYear(DateTime d) => DateFormat('MMMM yyyy').format(d);

  /// "Today", "Tomorrow", "Yesterday", "In 3 days", "3 days ago".
  static String relativeDay(DateTime d) {
    final n = daysUntil(d);
    return switch (n) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      > 1 && < 8 => 'In $n days',
      < -1 && > -8 => '${-n} days ago',
      _ => date(d),
    };
  }

  /// Short "time ago" label for activity feeds.
  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return dateShort(d);
  }

  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String percent(double v) => '${(v * 100).round()}%';

  static String number(num v) => NumberFormat.decimalPattern().format(v);

  static String fileSize(int kb) => kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '$kb KB';
}

class CurrencyInfo {
  const CurrencyInfo(this.code, this.symbol, this.name, this.locale);
  final String code;
  final String symbol;
  final String name;
  final String locale;
}

const supportedCurrencies = [
  CurrencyInfo('INR', '₹', 'Indian Rupee', 'en_IN'),
  CurrencyInfo('USD', r'$', 'US Dollar', 'en_US'),
  CurrencyInfo('EUR', '€', 'Euro', 'de_DE'),
  CurrencyInfo('GBP', '£', 'British Pound', 'en_GB'),
  CurrencyInfo('AED', 'AED ', 'UAE Dirham', 'en_AE'),
];

CurrencyInfo currencyFor(String code) =>
    supportedCurrencies.firstWhere((c) => c.code == code, orElse: () => supportedCurrencies.first);

String formatMoney(num value, String code, {bool compact = false}) {
  final c = currencyFor(code);
  if (compact) return '${value < 0 ? '-' : ''}${c.symbol}${_compact(value.abs().toDouble(), c.code == 'INR')}';
  final f = NumberFormat.currency(locale: c.locale, symbol: c.symbol, decimalDigits: value % 1 == 0 ? 0 : 2);
  return f.format(value);
}

String _compact(double v, bool indian) {
  String trim(double x) => x.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  if (indian) {
    if (v >= 1e7) return '${trim(v / 1e7)}Cr';
    if (v >= 1e5) return '${trim(v / 1e5)}L';
  } else {
    if (v >= 1e9) return '${trim(v / 1e9)}B';
    if (v >= 1e6) return '${trim(v / 1e6)}M';
  }
  if (v >= 1e3) return '${trim(v / 1e3)}K';
  return v.round().toString();
}

/// Currency formatting that follows the user's currency preference.
extension MoneyRef on WidgetRef {
  String money(num value, {bool compact = false}) =>
      formatMoney(value, watch(settingsProvider.select((s) => s.currency)), compact: compact);
}

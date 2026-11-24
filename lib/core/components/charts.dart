import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import 'app_card.dart';

class ChartSeries {
  const ChartSeries({required this.label, required this.color, required this.values});
  final String label;
  final Color color;
  final List<double> values;
}

class ChartSlice {
  const ChartSlice({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
}

/// Rounds the axis maximum up to a "nice" number and returns it with its interval.
({double max, double step}) _niceScale(double rawMax, {int ticks = 4}) {
  if (rawMax <= 0) return (max: ticks.toDouble(), step: 1);
  final rawStep = rawMax / ticks;
  final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final n = rawStep / mag;
  final nice = n <= 1 ? 1 : (n <= 2 ? 2 : (n <= 2.5 ? 2.5 : (n <= 5 ? 5 : 10)));
  final step = nice * mag;
  return (max: step * (rawMax / step).ceil(), step: step);
}

FlTitlesData _titles({
  required List<String> labels,
  required String Function(double) format,
  required double step,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 46,
        interval: step,
        getTitlesWidget: (v, meta) => v == meta.max
            ? const SizedBox.shrink()
            : SideTitleWidget(meta: meta, space: 6, child: Text(format(v), style: AppText.caption.copyWith(fontSize: 10.5))),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.toInt();
          if (i < 0 || i >= labels.length || v != i.toDouble()) return const SizedBox.shrink();
          return SideTitleWidget(meta: meta, space: 8, child: Text(labels[i], style: AppText.caption));
        },
      ),
    ),
  );
}

FlGridData _grid(double step) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: step,
      getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
    );

/// Grouped bar chart (one rod per series per label).
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.format,
    this.height = 210,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double) format;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = series.expand((s) => s.values).fold<double>(0, math.max);
    final scale = _niceScale(maxValue);
    final rodWidth = series.length > 1 ? 9.0 : 18.0;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: scale.max,
          alignment: BarChartAlignment.spaceAround,
          gridData: _grid(scale.step),
          borderData: FlBorderData(show: false),
          titlesData: _titles(labels: labels, format: format, step: scale.step),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${series[ri].label}\n',
                AppText.caption.copyWith(color: Colors.white70),
                children: [
                  TextSpan(text: format(rod.toY), style: AppText.labelStrong.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < labels.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 4,
                barRods: [
                  for (final s in series)
                    BarChartRodData(
                      toY: i < s.values.length ? s.values[i] : 0,
                      color: s.color,
                      width: rodWidth,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Smooth multi-series line chart with soft area fill.
class AppLineChart extends StatelessWidget {
  const AppLineChart({
    super.key,
    required this.labels,
    required this.series,
    required this.format,
    this.height = 210,
    this.fill = true,
  });

  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double) format;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final maxValue = series.expand((s) => s.values).fold<double>(0, math.max);
    final scale = _niceScale(maxValue);

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: scale.max,
          minX: 0,
          maxX: math.max(0, labels.length - 1).toDouble(),
          gridData: _grid(scale.step),
          borderData: FlBorderData(show: false),
          titlesData: _titles(labels: labels, format: format, step: scale.step),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              tooltipBorderRadius: BorderRadius.circular(10),
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${series[s.barIndex].label}\n',
                    AppText.caption.copyWith(color: Colors.white70),
                    children: [TextSpan(text: format(s.y), style: AppText.labelStrong.copyWith(color: Colors.white))],
                  ),
              ],
            ),
          ),
          lineBarsData: [
            for (final s in series)
              LineChartBarData(
                spots: [for (var i = 0; i < s.values.length; i++) FlSpot(i.toDouble(), s.values[i])],
                isCurved: true,
                curveSmoothness: 0.25,
                preventCurveOverShooting: true,
                color: s.color,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) =>
                      FlDotCirclePainter(radius: 3.5, color: Colors.white, strokeWidth: 2.5, strokeColor: s.color),
                ),
                belowBarData: BarAreaData(show: fill && series.length == 1, color: AppColors.tint(s.color, 0.1)),
              ),
          ],
        ),
        duration: const Duration(milliseconds: 400),
      ),
    );
  }
}

/// Donut chart with a centre label and an optional legend underneath.
class AppDonutChart extends StatelessWidget {
  const AppDonutChart({
    super.key,
    required this.slices,
    this.centerValue,
    this.centerLabel,
    this.size = 168,
    this.valueFormat,
    this.showLegend = true,
  });

  final List<ChartSlice> slices;
  final String? centerValue;
  final String? centerLabel;
  final double size;
  final String Function(double)? valueFormat;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final visible = slices.where((s) => s.value > 0).toList();
    final total = visible.fold<double>(0, (s, e) => s + e.value);

    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: size * 0.32,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: visible.isEmpty
                      ? [PieChartSectionData(value: 1, color: AppColors.border, radius: size * 0.16, showTitle: false)]
                      : [
                          for (final s in visible)
                            PieChartSectionData(value: s.value, color: s.color, radius: size * 0.16, showTitle: false),
                        ],
                ),
                duration: const Duration(milliseconds: 400),
              ),
              if (centerValue != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerValue!, style: AppText.metric.copyWith(fontSize: 22)),
                    if (centerLabel != null) Text(centerLabel!, style: AppText.caption),
                  ],
                ),
            ],
          ),
        ),
        if (showLegend) ...[
          const SizedBox(height: 20),
          ChartLegend(
            items: [
              for (final s in slices)
                (
                  label: s.label,
                  color: s.color,
                  value: valueFormat != null
                      ? valueFormat!(s.value)
                      : (total == 0 ? '0%' : '${(s.value / total * 100).round()}%'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Legend rendered as a two-column wrap of "dot label ... value".
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});
  final List<({String label, Color color, String? value})> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth >= 300 ? (c.maxWidth - 16) / 2 : c.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            for (final i in items)
              SizedBox(
                width: w,
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: i.color, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.label, style: AppText.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (i.value != null) Text(i.value!, style: AppText.labelStrong),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Card wrapper with title, optional subtitle/trailing and legend for charts.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.title, required this.child, this.subtitle, this.trailing, this.legend});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final List<({String label, Color color, String? value})>? legend;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                    Text(title, style: AppText.cardTitle),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: AppText.caption)],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (legend != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final l in legend!)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: l.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(l.label, style: AppText.caption),
                  ]),
              ],
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../reports_api.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _api = ReportsApi();
  Map<String, dynamic>? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await _api.getDailyReport();
      if (mounted) setState(() { _report = report; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }

    if (_report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            const Text('No report available', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Refresh')),
          ],
        ),
      );
    }

    final riskScore = (_report!['overall_risk_score'] as num?)?.toDouble() ?? 0.0;
    final threats = _report!['threats_detected'] as int? ?? 0;
    final apps = _report!['apps_scanned'] as int? ?? 0;
    final links = _report!['links_scanned'] as int? ?? 0;
    final calls = _report!['calls_analyzed'] as int? ?? 0;
    final recommendations = (_report!['recommendations'] as List?)?.cast<String>() ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Security Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _report!['report_date'] as String? ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),

            // Risk gauge
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('Overall Risk Score', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                value: riskScore,
                                color: riskScore < 30 ? AppTheme.success : riskScore < 60 ? AppTheme.warning : AppTheme.errorColor,
                                radius: 20,
                                showTitle: false,
                              ),
                              PieChartSectionData(
                                value: 100 - riskScore,
                                color: AppTheme.surface,
                                radius: 20,
                                showTitle: false,
                              ),
                            ],
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${riskScore.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text('/100', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            Row(
              children: [
                Expanded(child: _statCard('Threats', '$threats', Icons.warning, AppTheme.errorColor)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Apps Scanned', '$apps', Icons.apps, AppTheme.accent)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statCard('Links Scanned', '$links', Icons.link, AppTheme.warning)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('Calls Analyzed', '$calls', Icons.phone, AppTheme.success)),
              ],
            ),
            const SizedBox(height: 20),

            // Threat chart
            if (threats > 0 || apps > 0 || links > 0) ...[
              Text('Activity Breakdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: [threats, apps, links, calls].fold<num>(0, (a, b) => a > b ? a : b).toDouble() + 2,
                    barGroups: [
                      _bar(0, threats.toDouble(), AppTheme.errorColor),
                      _bar(1, apps.toDouble(), AppTheme.accent),
                      _bar(2, links.toDouble(), AppTheme.warning),
                      _bar(3, calls.toDouble(), AppTheme.success),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            const labels = ['Threats', 'Apps', 'Links', 'Calls'];
                            final i = v.toInt();
                            if (i < 0 || i >= labels.length) return const Text('');
                            return Text(labels[i], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10));
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Recommendations
            Text('Recommendations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...recommendations.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: const TextStyle(color: AppTheme.background, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y == 0 ? 0.1 : y,
          color: color,
          width: 20,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ],
    );
  }
}

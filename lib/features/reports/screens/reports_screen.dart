import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme.dart';
import '../reports_api.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final _api = ReportsApi();
  Map<String, dynamic>? _report;
  Map<String, dynamic>? _weeklyInsights;
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final report = await _api.getDailyReport();
      Map<String, dynamic>? weekly;
      try { weekly = await _api.getWeeklyInsights(); } catch (_) {}
      if (mounted) setState(() { _report = report; _weeklyInsights = weekly; _loading = false; });
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

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.today), text: 'Today'),
            Tab(icon: Icon(Icons.trending_up), text: '7-Day Trend'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyTab(),
              _buildWeeklyTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTab() {
    final riskScore = (_report!['overall_risk_score'] as num?)?.toDouble() ?? 0.0;
    final safetyScore = (100 - riskScore).clamp(0.0, 100.0);
    final threats = _report!['threats_detected'] as int? ?? 0;
    final apps = _report!['apps_scanned'] as int? ?? 0;
    final links = _report!['links_scanned'] as int? ?? 0;
    final calls = _report!['calls_analyzed'] as int? ?? 0;
    final recommendations = (_report!['recommendations'] as List?)?.cast<String>() ?? [];

    final safetyColor = safetyScore >= 70 ? AppTheme.success : safetyScore >= 40 ? AppTheme.warning : AppTheme.errorColor;
    final safetyLabel = safetyScore >= 70 ? 'GOOD' : safetyScore >= 40 ? 'FAIR' : 'AT RISK';

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security Report — ${_report!['report_date'] as String? ?? ''}',
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),

            // Gamified Safety Score
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [safetyColor.withValues(alpha: 0.2), AppTheme.cardColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: safetyColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        safetyScore >= 70 ? Icons.shield : safetyScore >= 40 ? Icons.shield_outlined : Icons.warning_amber_rounded,
                        color: safetyColor, size: 44,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cyber Safety Score', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          Row(
                            children: [
                              Text(safetyScore.toStringAsFixed(0), style: TextStyle(color: safetyColor, fontSize: 48, fontWeight: FontWeight.bold, height: 1)),
                              const Text('/100', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: safetyColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(safetyLabel, style: TextStyle(color: safetyColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: safetyScore / 100,
                      minHeight: 10,
                      backgroundColor: AppTheme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(safetyColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    safetyScore >= 70
                        ? 'Great job! Your device is well protected.'
                        : safetyScore >= 40
                            ? 'Some risks detected. Review recommendations below.'
                            : 'Immediate attention needed. Follow the tips below.',
                    style: TextStyle(color: safetyColor.withValues(alpha: 0.8), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                _statCard('Threats', '$threats', Icons.warning, AppTheme.errorColor),
                _statCard('Apps Scanned', '$apps', Icons.apps, AppTheme.accent),
                _statCard('Links Scanned', '$links', Icons.link, AppTheme.warning),
                _statCard('Calls Analyzed', '$calls', Icons.phone, AppTheme.success),
              ],
            ),
            const SizedBox(height: 20),

            // Activity chart
            if (threats > 0 || apps > 0 || links > 0) ...[
              Text('Activity Breakdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
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
                            return Text(labels[i], style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9));
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

            // AI Personalized Tips
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 16),
              const SizedBox(width: 6),
              Text('AI Security Tips', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            const Text('Personalized based on your security data today', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 10),
            ...recommendations.asMap().entries.map((e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: const Border(left: BorderSide(color: AppTheme.accent, width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: AppTheme.background, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4))),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyTab() {
    if (_weeklyInsights == null) {
      return const Center(child: Text('No weekly data available yet. Check back after a few days.', style: TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center));
    }

    final trend = _weeklyInsights!['trend'] as String? ?? 'stable';
    final avgScore = (_weeklyInsights!['average_risk_score'] as num?)?.toDouble() ?? 0;
    final avgSafetyScore = (100 - avgScore).clamp(0.0, 100.0);
    final dailyScores = (_weeklyInsights!['daily_scores'] as List?) ?? [];
    final totalThreats = _weeklyInsights!['total_threats'] as int? ?? 0;
    final totalLinks = _weeklyInsights!['total_links_scanned'] as int? ?? 0;

    final trendColor = trend == 'improving' ? AppTheme.success : trend == 'worsening' ? AppTheme.errorColor : AppTheme.warning;
    final trendIcon = trend == 'improving' ? Icons.trending_up : trend == 'worsening' ? Icons.trending_down : Icons.trending_flat;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Period: ${_weeklyInsights!['period'] ?? ''}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
            const SizedBox(height: 16),

            // Trend card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: trendColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(trendIcon, color: trendColor, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Security Trend: ${trend.toUpperCase()}', style: TextStyle(color: trendColor, fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Avg Safety Score: ${avgSafetyScore.toStringAsFixed(0)}/100', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weekly stats
            Row(
              children: [
                Expanded(child: _statCard('Total Threats', '$totalThreats', Icons.warning, AppTheme.errorColor)),
                const SizedBox(width: 10),
                Expanded(child: _statCard('Links Scanned', '$totalLinks', Icons.link, AppTheme.warning)),
              ],
            ),
            const SizedBox(height: 16),

            // Daily trend chart
            if (dailyScores.isNotEmpty) ...[
              Text('Daily Safety Score', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                height: 160,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.accent.withValues(alpha: 0.1), strokeWidth: 1),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= dailyScores.length) return const Text('');
                            try {
                              final date = DateTime.parse(dailyScores[i]['date'] as String);
                              return Text('${date.day}/${date.month}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9));
                            } catch (_) { return const Text(''); }
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: dailyScores.asMap().entries.map((e) {
                          final riskScore = (e.value['risk_score'] as num?)?.toDouble() ?? 0;
                          return FlSpot(e.key.toDouble(), (100 - riskScore).clamp(0.0, 100.0));
                        }).toList(),
                        isCurved: true,
                        color: AppTheme.accent,
                        barWidth: 3,
                        belowBarData: BarAreaData(show: true, color: AppTheme.accent.withValues(alpha: 0.1)),
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                    minY: 0,
                    maxY: 100,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_weeklyInsights!['best_day'] != null) ...[
              _insightRow(Icons.star, AppTheme.success, 'Best Day', _weeklyInsights!['best_day'].toString()),
              const SizedBox(height: 8),
              _insightRow(Icons.warning, AppTheme.errorColor, 'Most Risk', _weeklyInsights!['worst_day'].toString()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _insightRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10, height: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [BarChartRodData(toY: y == 0 ? 0.1 : y, color: color, width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
    );
  }
}

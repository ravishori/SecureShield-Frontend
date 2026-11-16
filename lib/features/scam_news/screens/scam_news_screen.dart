import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../community_scam/community_scam_api.dart';

class ScamNewsScreen extends StatefulWidget {
  const ScamNewsScreen({super.key});

  @override
  State<ScamNewsScreen> createState() => _ScamNewsScreenState();
}

class _ScamNewsScreenState extends State<ScamNewsScreen> {
  final _api = CommunityScamApi();
  final _cityCtrl = TextEditingController();
  Map<String, dynamic>? _feed;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({String? city}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final feed = await _api.getScamNewsFeed(city: city);
      setState(() {
        _feed = feed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load scam news. Check your connection.';
        _loading = false;
      });
    }
  }

  void _filterByCity() {
    final city = _cityCtrl.text.trim();
    _load(city: city.isEmpty ? null : city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Scam News Feed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _load(city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim()),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF00E5FF),
          onRefresh: () => _load(city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim()),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _filterBar(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
                  )
                else if (_error != null)
                  _errorState()
                else if (_feed != null) ...[
                  _headerCard(_feed!),
                  const SizedBox(height: 16),
                  ..._buildItems(_feed!),
                ],
                const SizedBox(height: 24),
                _ctaCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFF00E5FF), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _cityCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Filter by city (e.g. Mumbai)',
                hintStyle: TextStyle(color: Color(0xFF6E7B8C)),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _filterByCity(),
            ),
          ),
          TextButton(
            onPressed: _filterByCity,
            child: const Text('Apply', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );
  }

  Widget _headerCard(Map<String, dynamic> feed) {
    final total = feed['total_reports_this_week'] ?? 0;
    final topCity = feed['top_city'];
    final weekStart = feed['week_starting'] ?? '';
    final weekEnd = feed['week_ending'] ?? '';
    final advisory = feed['advisory'] ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFFF5252)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5252).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'This week in scams',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$weekStart → $weekEnd',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statBubble('$total', 'reports'),
              const SizedBox(width: 12),
              if (topCity != null) _statBubble(topCity.toString(), 'top city'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            advisory,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statBubble(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildItems(Map<String, dynamic> feed) {
    final items = (feed['items'] as List?) ?? const [];
    if (items.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2233),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'No scam reports yet this week — good news. Stay vigilant.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ];
    }
    return items.cast<Map<String, dynamic>>().map(_newsCard).toList();
  }

  Widget _newsCard(Map<String, dynamic> item) {
    final severity = (item['severity'] ?? 'info').toString();
    final color = _severityColor(severity);
    final source = (item['source'] ?? 'community').toString();
    final reports = item['reports_in_period'] ?? 0;
    final phones = (item['sample_phones'] as List?)?.cast<String>() ?? [];
    final urls = (item['sample_urls'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(severity.toUpperCase(), color),
              const SizedBox(width: 8),
              _badge(source.toUpperCase(), const Color(0xFF7C4DFF)),
              if (reports > 0) ...[
                const SizedBox(width: 8),
                _badge('$reports REPORTS', const Color(0xFF00E5FF)),
              ],
              const Spacer(),
              if (item['region'] != null)
                Flexible(
                  child: Text(
                    item['region'].toString(),
                    style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item['headline'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item['summary'] ?? '',
            style: const TextStyle(color: Color(0xFF90A4AE), fontSize: 13, height: 1.4),
          ),
          if (phones.isNotEmpty || urls.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFF2C3A52), height: 1),
            const SizedBox(height: 10),
            const Text(
              'Reported indicators',
              style: TextStyle(
                color: Color(0xFF90A4AE),
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...phones.map((p) => _copyableChip(Icons.phone, p)),
                ...urls.map((u) => _copyableChip(Icons.link, u)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _copyableChip(IconData icon, String text) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied: $text'), duration: const Duration(seconds: 1)),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0E27),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2C3A52)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF00E5FF), size: 12),
            const SizedBox(width: 4),
            Text(
              text.length > 32 ? '${text.substring(0, 30)}…' : text,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.copy, color: Color(0xFF90A4AE), size: 11),
          ],
        ),
      ),
    );
  }

  Widget _ctaCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_alert, color: Color(0xFF4CAF50)),
              SizedBox(width: 8),
              Text(
                'Spotted a scam?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Help the community. Reporting a scam takes 30 seconds and protects thousands of others.',
            style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.push('/community-scams'),
            icon: const Icon(Icons.flag, size: 18),
            label: const Text('Report a scam now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF90A4AE), size: 36),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _load(city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim()),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const Color(0xFFFF1744);
      case 'warning':
        return const Color(0xFFFF9800);
      case 'info':
      default:
        return const Color(0xFF00E5FF);
    }
  }
}

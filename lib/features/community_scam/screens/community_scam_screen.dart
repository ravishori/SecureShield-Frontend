import 'package:secureshield_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../community_scam_api.dart';

class CommunityScamScreen extends StatefulWidget {
  const CommunityScamScreen({super.key});

  @override
  State<CommunityScamScreen> createState() => _CommunityScamScreenState();
}

class _CommunityScamScreenState extends State<CommunityScamScreen>
    with SingleTickerProviderStateMixin {
  final _api = CommunityScamApi();
  late TabController _tabController;
  List<dynamic> _feed = [];
  List<dynamic> _trending = [];
  bool _loading = true;
  String? _filterCity;

  static const scamTypes = [
    {'value': 'phishing_link', 'label': 'Phishing Link'},
    {'value': 'fake_job', 'label': 'Fake Job'},
    {'value': 'lottery_fraud', 'label': 'Lottery Fraud'},
    {'value': 'investment_scam', 'label': 'Investment Scam'},
    {'value': 'bank_fraud', 'label': 'Bank Fraud'},
    {'value': 'otp_fraud', 'label': 'OTP Fraud'},
    {'value': 'romance_scam', 'label': 'Romance Scam'},
    {'value': 'tech_support_scam', 'label': 'Tech Support Scam'},
    {'value': 'parcel_scam', 'label': 'Parcel Scam'},
    {'value': 'other', 'label': 'Other'},
  ];

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
      final feed = await _api.getFeed(city: _filterCity);
      final trending = await _api.getTrending(city: _filterCity);
      if (mounted) setState(() { _feed = feed; _trending = trending; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showReportDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String selectedType = 'other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context).csReport, style: const TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  dropdownColor: AppTheme.surface,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: AppLocalizations.of(context).csType, labelStyle: const TextStyle(color: AppTheme.textSecondary)),
                  items: scamTypes.map((t) => DropdownMenuItem<String>(
                    value: t['value'],
                    child: Text(t['label']!),
                  )).toList(),
                  onChanged: (v) => setStateDlg(() => selectedType = v ?? 'other'),
                ),
                const SizedBox(height: 8),
                TextField(controller: titleCtrl, style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: AppLocalizations.of(context).csTitleReq, labelStyle: const TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(height: 8),
                TextField(controller: descCtrl, maxLines: 3, style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: AppLocalizations.of(context).csDescReq, labelStyle: const TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(height: 8),
                TextField(controller: phoneCtrl, style: const TextStyle(color: AppTheme.textPrimary), keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Scammer\'s Phone (optional)', labelStyle: TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(height: 8),
                TextField(controller: urlCtrl, style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: AppLocalizations.of(context).csUrl, labelStyle: const TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(height: 8),
                TextField(controller: cityCtrl, style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(labelText: AppLocalizations.of(context).csCity, labelStyle: const TextStyle(color: AppTheme.textSecondary))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                try {
                  await _api.reportScam(
                    scamType: selectedType,
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
                    city: cityCtrl.text.trim().isEmpty ? null : cityCtrl.text.trim(),
                  );
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scam reported — thank you for protecting the community!'), backgroundColor: AppTheme.success),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
              child: Text(AppLocalizations.of(context).gReport),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).csTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined, color: AppTheme.accent),
            onPressed: _showFilterDialog,
            tooltip: AppLocalizations.of(context).csFilterCity,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(icon: Icon(Icons.feed), text: 'Latest'),
            Tab(icon: Icon(Icons.trending_up), text: 'Trending'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportDialog,
        backgroundColor: AppTheme.errorColor,
        icon: const Icon(Icons.add_alert),
        label: Text(AppLocalizations.of(context).csReportBtn),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeed(_feed),
                _buildFeed(_trending),
              ],
            ),
    );
  }

  Widget _buildFeed(List<dynamic> reports) {
    if (reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 64, color: AppTheme.success),
            const SizedBox(height: 16),
            Text(_filterCity != null ? 'No scams reported in $_filterCity yet' : 'No scams reported yet',
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).csBeFirst, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.accent,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: reports.length,
        itemBuilder: (context, i) => _scamCard(reports[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _scamCard(Map<String, dynamic> report) {
    final scamType = report['scam_type'] as String? ?? 'other';
    final typeLabel = scamTypes.firstWhere((t) => t['value'] == scamType, orElse: () => {'label': 'Other'})['label']!;
    final upvotes = report['upvotes'] as int? ?? 0;
    final isVerified = report['is_verified'] as bool? ?? false;
    final city = report['city'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(typeLabel, style: const TextStyle(color: AppTheme.errorColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (isVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: AppTheme.accent, size: 14),
                  const Text(' Verified', style: TextStyle(color: AppTheme.accent, fontSize: 10)),
                ],
                const Spacer(),
                if (city != null)
                  Text(city, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(report['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              report['description'] as String? ?? '',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (report['phone_number'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone, color: AppTheme.errorColor, size: 12),
                const SizedBox(width: 4),
                Text(report['phone_number'] as String, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ]),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await _api.upvote(report['id'] as String);
                    await _load();
                  },
                  child: Row(children: [
                    const Icon(Icons.thumb_up_outlined, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 4),
                    Text('$upvotes helpful', style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                  ]),
                ),
                const Spacer(),
                Text(
                  _formatDate(report['created_at'] as String? ?? ''),
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    final ctrl = TextEditingController(text: _filterCity);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(AppLocalizations.of(context).csFilterByCity, style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(labelText: AppLocalizations.of(context).csCityHint, labelStyle: const TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _filterCity = null);
              Navigator.pop(ctx);
              _load();
            },
            child: Text(AppLocalizations.of(context).gClear, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _filterCity = ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
              Navigator.pop(ctx);
              _load();
            },
            child: Text(AppLocalizations.of(context).gApply),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return iso;
    }
  }
}

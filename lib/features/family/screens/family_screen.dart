import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/banking_threat_correlator.dart';
import '../../../core/security/banking_threat_provider.dart';
import '../../../core/theme.dart';
import '../../banking_protection/widgets/banking_threat_strip.dart';
import '../family_api.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> with SingleTickerProviderStateMixin {
  final _api = FamilyApi();
  List<dynamic> _members = [];
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
      final members = await _api.getMembers();
      if (mounted) setState(() { _members = members; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddMemberDialog({bool isChild = false}) {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController(text: isChild ? 'Child' : '');
    bool canViewAlerts = !isChild;
    bool canTriggerPanic = false;
    bool isChildProfile = isChild;
    bool contentFilterEnabled = isChild;
    bool cyberbullyingAlerts = isChild;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(isChild ? Icons.child_care : Icons.person_add, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(isChild ? 'Add Child Profile' : 'Add Family Member', style: const TextStyle(color: AppTheme.textPrimary)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: phoneCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Phone Number', labelStyle: TextStyle(color: AppTheme.textSecondary)),
                  keyboardType: TextInputType.phone),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Name / Nickname', labelStyle: TextStyle(color: AppTheme.textSecondary))),
                const SizedBox(height: 8),
                TextField(controller: relCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(labelText: 'Relationship', labelStyle: TextStyle(color: AppTheme.textSecondary))),
                const Divider(height: 20),
                if (!isChild) ...[
                  CheckboxListTile(
                    value: canViewAlerts,
                    onChanged: (v) => setStateDlg(() => canViewAlerts = v ?? false),
                    title: const Text('Can view my alerts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    activeColor: AppTheme.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: canTriggerPanic,
                    onChanged: (v) => setStateDlg(() => canTriggerPanic = v ?? false),
                    title: const Text('Can trigger panic alert', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    activeColor: AppTheme.accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
                if (isChild) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Child profiles have additional safety features enabled by default.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                  ),
                  CheckboxListTile(
                    value: contentFilterEnabled,
                    onChanged: (v) => setStateDlg(() => contentFilterEnabled = v ?? false),
                    title: const Text('Content filter (block unsafe links)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    activeColor: const Color(0xFF7C4DFF),
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    value: cyberbullyingAlerts,
                    onChanged: (v) => setStateDlg(() => cyberbullyingAlerts = v ?? false),
                    title: const Text('Cyberbullying alerts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    activeColor: const Color(0xFF7C4DFF),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _api.addMember(
                    memberPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    nickname: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
                    relationship: relCtrl.text.trim().isEmpty ? null : relCtrl.text.trim(),
                    canViewAlerts: canViewAlerts,
                    canTriggerPanic: canTriggerPanic,
                    isChildProfile: isChildProfile,
                    contentFilterEnabled: contentFilterEnabled,
                    cyberbullyingAlerts: cyberbullyingAlerts,
                  );
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isChild ? 'Child profile added with safety features' : 'Family member added'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isChild ? const Color(0xFF7C4DFF) : AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: Text(isChild ? 'Add Child' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adults = _members.where((m) => m['is_child_profile'] != true).toList();
    final children = _members.where((m) => m['is_child_profile'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Safety Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(icon: const Icon(Icons.family_restroom), text: 'Family (${adults.length})'),
            Tab(icon: const Icon(Icons.child_care), text: 'Kids (${children.length})'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person_add),
            onSelected: (v) => _showAddMemberDialog(isChild: v == 'child'),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'adult', child: Row(children: [Icon(Icons.person, size: 16), SizedBox(width: 8), Text('Add Adult Member')])),
              const PopupMenuItem(value: 'child', child: Row(children: [Icon(Icons.child_care, size: 16), SizedBox(width: 8), Text('Add Child Profile')])),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
              children: [
                // ── Guardian alert strip ─────────────────────────────────
                // When threats are present, this warns the family member /
                // guardian that their primary device is currently exposed,
                // which is critical for elderly-protection scenarios where
                // the guardian is reviewing their parent's account remotely.
                const _FamilyThreatAlert(),

                // ── Original tab content ────────────────────────────────
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMemberList(adults, isChildTab: false),
                      _buildChildList(children),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMemberList(List<dynamic> members, {required bool isChildTab}) {
    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isChildTab ? Icons.child_care : Icons.family_restroom, size: 64, color: AppTheme.accent),
            const SizedBox(height: 16),
            Text(isChildTab ? 'No child profiles added' : 'No family members added', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              isChildTab ? 'Add child profiles to enable safety features' : 'Add family members to share safety alerts',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddMemberDialog(isChild: isChildTab),
              icon: Icon(isChildTab ? Icons.child_care : Icons.person_add),
              label: Text(isChildTab ? 'Add Child Profile' : 'Add Member'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, i) => _memberCard(members[i] as Map<String, dynamic>),
    );
  }

  Widget _buildChildList(List<dynamic> children) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
          child: const Row(children: [
            Icon(Icons.shield, color: Color(0xFF7C4DFF), size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Child profiles have content filtering and cyberbullying detection enabled',
                style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 12),
              ),
            ),
          ]),
        ),
        Expanded(child: _buildMemberList(children, isChildTab: true)),
      ],
    );
  }

  Widget _memberCard(Map<String, dynamic> member) {
    final isChild = member['is_child_profile'] as bool? ?? false;
    final hasContentFilter = member['content_filter_enabled'] as bool? ?? false;
    final hasBullyingAlert = member['cyberbullying_alerts'] as bool? ?? false;
    final accentColor = isChild ? const Color(0xFF7C4DFF) : AppTheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor,
                  child: Icon(
                    isChild ? Icons.child_care : Icons.person,
                    color: isChild ? const Color(0xFF7C4DFF) : AppTheme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member['nickname'] as String? ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      if (member['relationship'] != null)
                        Text(member['relationship'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor, size: 20),
                  onPressed: () async {
                    await _api.removeMember(member['id'] as String);
                    await _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (member['can_view_alerts'] == true) _badge(Icons.notifications, 'Alerts', AppTheme.accent),
                if (member['can_trigger_panic'] == true) _badge(Icons.sos, 'Panic', AppTheme.errorColor),
                if (isChild) _badge(Icons.child_care, 'Child Profile', const Color(0xFF7C4DFF)),
                if (hasContentFilter) _badge(Icons.filter_alt, 'Content Filter', AppTheme.success),
                if (hasBullyingAlert) _badge(Icons.security, 'Bullying Alert', AppTheme.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Family-screen specific threat alert
//
// FamilyScreen is a plain StatefulWidget (not Consumer), so we wrap the
// banking-threat strip in a small Consumer here. Also adds a guardian-
// context preface — guardians monitoring an elderly parent need to know
// that the parent's device may be compromised RIGHT NOW.
// ────────────────────────────────────────────────────────────────────────────
class _FamilyThreatAlert extends ConsumerWidget {
  const _FamilyThreatAlert();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(bankingThreatReportProvider);
    if (report == null || !report.hasThreats) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isCritical = report.level == BankingThreatLevel.critical;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guardian-context preface
          Row(
            children: [
              Icon(
                Icons.shield_moon_outlined,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isCritical
                      ? 'Active threats on this device — your family members are at risk:'
                      : 'Caution recommended for family banking activity:',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          BankingThreatStrip(
            report: report,
            margin: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

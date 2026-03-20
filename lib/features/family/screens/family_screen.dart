import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../family_api.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _api = FamilyApi();
  List<dynamic> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  void _showAddMemberDialog() {
    final phoneCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    bool canViewAlerts = false;
    bool canTriggerPanic = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add Family Member', style: TextStyle(color: AppTheme.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nickname')),
                const SizedBox(height: 8),
                TextField(controller: relCtrl, decoration: const InputDecoration(labelText: 'Relationship (e.g. Parent, Child)')),
                const SizedBox(height: 8),
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
                  );
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Family member added'), backgroundColor: AppTheme.success),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Add'),
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
        title: const Text('Family Dashboard'),
        actions: [IconButton(icon: const Icon(Icons.person_add), onPressed: _showAddMemberDialog)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _members.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.family_restroom, size: 64, color: AppTheme.accent),
                      const SizedBox(height: 16),
                      const Text('No family members added', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      const Text('Add family members to share safety alerts', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _showAddMemberDialog, icon: const Icon(Icons.person_add), label: const Text('Add Member')),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _members.length,
                  itemBuilder: (context, i) {
                    final member = _members[i] as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.primary,
                          child: Text(
                            (member['nickname'] as String? ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(member['nickname'] as String? ?? 'Unknown', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (member['relationship'] != null)
                              Text(member['relationship'] as String, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (member['can_view_alerts'] == true)
                                  _badge(Icons.notifications, 'Alerts', AppTheme.accent),
                                const SizedBox(width: 4),
                                if (member['can_trigger_panic'] == true)
                                  _badge(Icons.sos, 'Panic', AppTheme.errorColor),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorColor),
                          onPressed: () async {
                            await _api.removeMember(member['id'] as String);
                            await _load();
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
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

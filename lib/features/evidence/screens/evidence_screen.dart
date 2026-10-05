import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme.dart';
import '../evidence_api.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

class EvidenceScreen extends StatefulWidget {
  const EvidenceScreen({super.key});

  @override
  State<EvidenceScreen> createState() => _EvidenceScreenState();
}

class _EvidenceScreenState extends State<EvidenceScreen> {
  final _api = EvidenceApi();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _api.getEvidence();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    FilePickerResult? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Add Evidence', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  picked = await FilePicker.platform.pickFiles(allowMultiple: false);
                  setStateDlg(() {});
                },
                icon: const Icon(Icons.attach_file),
                label: Text(picked != null ? 'File selected' : 'Pick File'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || picked == null) return;
                Navigator.pop(ctx);
                try {
                  await _api.uploadEvidence(
                    title: titleCtrl.text.trim(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                    filePath: picked!.files.single.path!,
                  );
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Evidence uploaded'), backgroundColor: AppTheme.success),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Upload'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'screenshot': return Icons.image;
      case 'audio': return Icons.audio_file;
      case 'video': return Icons.video_file;
      default: return Icons.description;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).evidenceLocker),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _upload),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_special, size: 64, color: AppTheme.accent),
                      const SizedBox(height: 16),
                      const Text('Evidence Locker is empty', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      const Text('Store screenshots, audio, and documents here', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _upload, icon: const Icon(Icons.add), label: const Text('Add Evidence')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.accent,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i] as Map<String, dynamic>;
                      final id = item['id'] as String;
                      final fileType = item['file_type'] as String? ?? 'document';
                      final sizeBytes = item['file_size_bytes'] as int? ?? 0;

                      return Dismissible(
                        key: Key(id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.surface,
                              title: const Text('Delete Evidence?', style: TextStyle(color: AppTheme.textPrimary)),
                              content: const Text('This action cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) async {
                          await _api.delete(id);
                          await _load();
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_typeIcon(fileType), color: AppTheme.accent, size: 22),
                            ),
                            title: Text(item['title'] as String? ?? '', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              '${fileType.toUpperCase()} • ${_formatSize(sizeBytes)}${item['case_id'] != null ? ' • Case: ${item['case_id']}' : ''}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            trailing: item['is_encrypted'] == true
                                ? const Icon(Icons.lock, color: AppTheme.accent, size: 16)
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

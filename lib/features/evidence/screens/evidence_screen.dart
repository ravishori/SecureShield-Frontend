import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _purgeDownloads();
    _load();
  }

  @override
  void dispose() {
    _purgeDownloads();
    super.dispose();
  }

  // Downloaded copies are sensitive and only needed while being opened/shared. A receiving app may read the shared
  // file well after the sheet and this screen are gone, so copies are removed only once they are older than this.
  static const _downloadGrace = Duration(minutes: 30);

  Future<Directory> _downloadsRoot() async {
    final base = await getTemporaryDirectory();
    return Directory('${base.path}${Platform.pathSeparator}evidence_downloads');
  }

  Future<void> _purgeDownloads() async {
    try {
      await _api.purgeDownloads(await _downloadsRoot(), olderThan: _downloadGrace);
    } catch (_) {/* best effort */}
  }

  /// Downloads the item (the server only serves the caller's own evidence) and hands it to the OS share sheet,
  /// from which it can be opened or saved.
  Future<void> _open(Map<String, dynamic> item) async {
    if (_openingId != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = item['id'] as String;
    setState(() => _openingId = id);
    try {
      final file = await _api.downloadEvidence(
        id: id,
        downloadsRoot: await _downloadsRoot(),
        expectedBytes: item['file_size_bytes'] as int?,
      );
      await Share.shareXFiles([XFile(file.path)], subject: item['title'] as String?);
    } on EvidenceDownloadException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.gone ? l10n.evFileGone : l10n.evDownloadFailed)));
      }
    } catch (_) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text(l10n.evDownloadFailed)));
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
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
          title: Text(AppLocalizations.of(context).evAdd, style: const TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context).gTitle)),
              const SizedBox(height: 8),
              TextField(controller: descCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context).evDescOpt)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  picked = await FilePicker.platform.pickFiles(
                    allowMultiple: false,
                    // keep in sync with backend app/services/upload_safety.py EVIDENCE_POLICY
                    type: FileType.custom,
                    allowedExtensions: const [
                      'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic',
                      'pdf', 'txt', 'doc', 'docx',
                      'mp3', 'wav', 'aac', 'm4a', 'ogg',
                      'mp4', 'mov', '3gp', 'avi', 'mkv', 'webm',
                    ],
                  );
                  setStateDlg(() {});
                },
                icon: const Icon(Icons.attach_file),
                label: Text(picked != null ? 'File selected' : 'Pick File'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context).cancel, style: const TextStyle(color: AppTheme.textSecondary))),
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
                      SnackBar(content: Text(AppLocalizations.of(context).evUploaded), backgroundColor: AppTheme.success),
                    );
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(AppLocalizations.of(context).gUpload),
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
                      Text(AppLocalizations.of(context).evEmpty, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
                      Text(AppLocalizations.of(context).evEmptyBody, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(onPressed: _upload, icon: const Icon(Icons.add), label: Text(AppLocalizations.of(context).evAdd)),
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
                              title: Text(AppLocalizations.of(context).evDeleteQ, style: const TextStyle(color: AppTheme.textPrimary)),
                              content: Text(AppLocalizations.of(context).evCannotUndo, style: const TextStyle(color: AppTheme.textSecondary)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context).cancel)),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(AppLocalizations.of(context).gDelete),
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
                            onTap: () => _open(item),
                            trailing: _openingId == id
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent))
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (item['is_encrypted'] == true)
                                        const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.lock, color: AppTheme.accent, size: 16)),
                                      Tooltip(message: AppLocalizations.of(context).evOpen, child: const Icon(Icons.open_in_new, color: AppTheme.accent, size: 18)),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

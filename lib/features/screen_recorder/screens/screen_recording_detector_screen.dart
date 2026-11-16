import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secureshield_app/l10n/app_localizations.dart';

import '../../../core/theme.dart';
import '../screen_recording_detector_service.dart';

/// Live status of "is my screen being recorded right now?" (Android 15+), with an in-session event log.
class ScreenRecordingDetectorScreen extends StatefulWidget {
  const ScreenRecordingDetectorScreen({super.key, ScreenRecordingDetectorService? service}) : _service = service;

  final ScreenRecordingDetectorService? _service;

  @override
  State<ScreenRecordingDetectorScreen> createState() => _ScreenRecordingDetectorScreenState();
}

class _ScreenRecordingDetectorScreenState extends State<ScreenRecordingDetectorScreen> {
  late final ScreenRecordingDetectorService _service = widget._service ?? ScreenRecordingDetectorService();
  StreamSubscription<bool>? _sub;
  bool? _supported; // null = still checking
  bool _recording = false;
  final List<({DateTime at, bool started})> _log = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final supported = await _service.isSupported();
    if (!mounted) return;
    setState(() => _supported = supported);
    if (!supported) return;
    final now = await _service.isRecording();
    if (!mounted) return;
    setState(() => _recording = now);
    _sub = _service.states.listen((recording) {
      if (!mounted || recording == _recording) return;
      setState(() {
        _recording = recording;
        _log.insert(0, (at: DateTime.now(), started: recording));
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _time(DateTime t) => t.toLocal().toString().substring(11, 19);

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.srdTitle)),
      body: _supported == null
          ? const Center(child: CircularProgressIndicator())
          : _supported == false
              ? _unsupported(t)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  _statusCard(t),
                  const SizedBox(height: 12),
                  Text(t.srdScope, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  Text(t.srdLog, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  if (_log.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t.srdNoEvents, style: const TextStyle(color: AppTheme.textSecondary)),
                    ),
                  for (final e in _log)
                    ListTile(
                      dense: true,
                      leading: Icon(e.started ? Icons.fiber_manual_record : Icons.stop_circle_outlined,
                          color: e.started ? AppTheme.errorColor : AppTheme.success),
                      title: Text(e.started ? t.srdStarted : t.srdStopped),
                      trailing: Text(_time(e.at)),
                    ),
                ]),
    );
  }

  Widget _unsupported(AppLocalizations t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline, size: 56, color: AppTheme.warning),
            const SizedBox(height: 12),
            Text(t.srdUnsupported, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(t.srdUnsupportedBody, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          ]),
        ),
      );

  Widget _statusCard(AppLocalizations t) {
    final color = _recording ? AppTheme.errorColor : AppTheme.success;
    return Card(
      key: const Key('srdStatus'),
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(_recording ? Icons.videocam : Icons.videocam_off, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_recording ? t.srdActive : t.srdIdle, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(_recording ? t.srdActiveBody : t.srdIdleBody, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
          ),
        ]),
      ),
    );
  }
}

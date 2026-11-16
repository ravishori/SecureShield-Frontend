import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/verdict/scam_verdict.dart';
import '../../core/verdict/verdict_adapters.dart';
import '../../core/verdict/verdict_response.dart';
import '../link_scanner/link_scanner_api.dart';
import '../message_analyzer/message_analyzer_api.dart';
import '../qr_scanner/qr_safety_service.dart';
import 'hub_input.dart';
import 'hub_result.dart';
import 'sensitive_content.dart';

/// The only two network calls the hub can make. Both are existing endpoints; the hub adds none.
abstract class HubGateway {
  Future<VerdictResponse> analyzeMessage(String text);
  Future<VerdictResponse> scanUrl(String url);
}

class ApiHubGateway implements HubGateway {
  @override
  // External AI is never requested from the hub, whatever the server switch says.
  Future<VerdictResponse> analyzeMessage(String text) => MessageAnalyzerApi().analyzeMessageWithVerdict(messageText: text, useAi: false);

  @override
  Future<VerdictResponse> scanUrl(String url) => LinkScannerApi().scanLinkWithVerdict(url);
}

final hubGatewayProvider = Provider<HubGateway>((_) => ApiHubGateway());

enum HubPhase { idle, confirming, analysing, result }

enum HubSource { paste, camera }

class HubState {
  final HubPhase phase;
  final HubRoute? route;
  final HubSource source;
  final String original; // what the user entered; held in memory only while confirming
  final String masked; // original with sensitive spans replaced; equals [original] when nothing was found
  final Set<SensitiveKind> sensitive;
  final HubOutcome? outcome;
  final String? error; // a local input problem; nothing was sent

  const HubState({
    this.phase = HubPhase.idle,
    this.route,
    this.source = HubSource.paste,
    this.original = '',
    this.masked = '',
    this.sensitive = const {},
    this.outcome,
    this.error,
  });

  bool get hasSensitive => sensitive.isNotEmpty;
}

FailureKind failureKindOf(Object e) {
  if (e is DioException) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return FailureKind.timeout;
      case DioExceptionType.connectionError:
        return FailureKind.network;
      case DioExceptionType.cancel:
        return FailureKind.cancelled;
      default:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) return FailureKind.auth;
        if (code == 429) return FailureKind.rateLimited;
        if (code == null) return FailureKind.network;
        return FailureKind.server;
    }
  }
  return FailureKind.server;
}

class ScamHubNotifier extends Notifier<HubState> {
  @override
  HubState build() => const HubState();

  HubGateway get _gateway => ref.read(hubGatewayProvider);

  /// Typed or pasted input. A URL or message goes to the confirmation step; nothing is sent yet.
  void submitPasted(String raw, {HubRoute? override}) {
    final c = classifyScamInput(raw);
    switch (c) {
      case HubRejected(:final reason):
        state = HubState(error: reason);
      case HubClassified(:final text, route: final detected):
        final route = override ?? detected; // the user may correct the detected type; the text itself is never changed
        if (route == HubRoute.url && text.length > hubMaxUrlChars) {
          state = const HubState(error: 'That link is too long. The limit is $hubMaxUrlChars characters.');
        } else if (route == HubRoute.qrPayload) {
          _showLocalQr(text, HubSource.paste);
        } else {
          _beginConfirm(route, text, HubSource.paste);
        }
    }
  }

  /// A camera-scanned QR payload: ALWAYS analysed on the device first; no network call is possible from here.
  void submitCamera(String raw) {
    if (raw.trim().isEmpty) {
      state = const HubState(error: 'The QR code was empty.', source: HubSource.camera);
      return;
    }
    if (raw.length > hubMaxChars) {
      state = const HubState(error: 'That QR code holds too much data to check. The limit is $hubMaxChars characters.', source: HubSource.camera);
      return;
    }
    _showLocalQr(raw, HubSource.camera);
  }

  void _showLocalQr(String payload, HubSource source) {
    final report = QrSafetyService.analyze(payload);
    final url = report.kind == QrPayloadKind.url ? report.extracted['url'] : null;
    state = HubState(
      phase: HubPhase.result,
      route: HubRoute.qrPayload,
      source: source,
      outcome: HubVerdict(HubRoute.qrPayload, report.toVerdict(), local: true, checkableUrl: (url != null && url.length <= hubMaxUrlChars) ? url : null),
    );
  }

  /// The user explicitly asked to check a QR-derived link's reputation. This only opens the confirmation step.
  void requestReputationCheck() {
    final o = state.outcome;
    if (o is HubVerdict && o.local && o.checkableUrl != null) {
      _beginConfirm(HubRoute.url, o.checkableUrl!, HubSource.camera);
    }
  }

  void _beginConfirm(HubRoute route, String text, HubSource source) {
    final spans = findSensitiveSpans(text);
    state = HubState(
      phase: HubPhase.confirming,
      route: route,
      source: source,
      original: text,
      masked: spans.isEmpty ? text : maskSensitive(text),
      sensitive: spans.map((s) => s.kind).toSet(),
    );
  }

  /// Back to input. The user's text is not changed; a QR-derived lookup returns to its local result.
  void cancelConfirm() {
    if (state.source == HubSource.camera && state.route == HubRoute.url) {
      _showLocalQr(state.original, HubSource.camera);
    } else {
      state = const HubState();
    }
  }

  /// Send exactly what the confirmation sheet showed. [useMasked] sends the masked version and never the original.
  Future<void> confirmSend({required bool useMasked}) async {
    if (state.phase != HubPhase.confirming) return; // ignores a double tap
    final route = state.route!;
    final source = state.source;
    final payload = (useMasked && state.hasSensitive) ? state.masked : state.original;
    state = HubState(phase: HubPhase.analysing, route: route, source: source); // drops both copies of the text
    try {
      final r = route == HubRoute.message ? await _gateway.analyzeMessage(payload) : await _gateway.scanUrl(payload);
      final v = r.verdict;
      state = HubState(
        phase: HubPhase.result,
        route: route,
        source: source,
        outcome: v != null
            ? HubVerdict(route, v)
            : HubVerdict(
                route,
                ScamVerdict.unknown(
                  sourceType: route == HubRoute.message ? SourceType.message : SourceType.url,
                  engineVersion: route == HubRoute.message ? 'message-patterns/1' : 'url-heuristics/1',
                  limitation: 'The server did not return a usable result, so no judgement is made.',
                ),
                synthesized: true,
              ),
      );
    } catch (e) {
      state = HubState(phase: HubPhase.result, route: route, source: source, outcome: HubRequestFailed(route, failureKindOf(e)));
    }
  }

  void reset() => state = const HubState();
}

final scamHubProvider = NotifierProvider<ScamHubNotifier, HubState>(ScamHubNotifier.new);

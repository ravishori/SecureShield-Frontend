import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';

/// Extended Dio options for AI-backed endpoints.
///
/// FIR draft generation now uses Claude Haiku 4.5 with a tighter token cap,
/// so most drafts complete in 8-20 seconds (English) or 15-30 seconds
/// (Devanagari / Tamil / Telugu — denser scripts emit 2-3× more tokens per
/// word). We keep a 60-second cap as a safety margin for the rare slow run
/// without leaving the user staring at the spinner forever.
final _aiRequestOptions = Options(
  receiveTimeout: const Duration(seconds: 60),
  sendTimeout: const Duration(seconds: 20),
);

class VideoCallApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> createRoom({
    String callType = 'police_report',
    String? incidentType,
    String? notes,
  }) async {
    final response = await _client.dio.post('/video-call/create-room', data: {
      'call_type': callType,
      if (incidentType != null) 'incident_type': incidentType,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateFir({
    required String incidentType,
    required String description,
    required String incidentDate,
    required String incidentLocation,
    required String complainantName,
    required String complainantPhone,
    String? suspectInfo,
    String? evidenceSummary,
    String? amountLost,
    String? language,
  }) async {
    final response = await _client.dio.post(
      '/video-call/generate-fir',
      data: {
        'incident_type':       incidentType,
        'description':         description,
        'incident_date':       incidentDate,
        'incident_location':   incidentLocation,
        'complainant_name':    complainantName,
        'complainant_phone':   complainantPhone,
        if (suspectInfo     != null) 'suspect_info':     suspectInfo,
        if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
        if (amountLost      != null) 'amount_lost':      amountLost,
        if (language        != null && language.isNotEmpty) 'language': language,
      },
      options: _aiRequestOptions,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Streams the FIR draft from `/video-call/generate-fir-stream`.
  ///
  /// Yields a sequence of [FirStreamEvent]s in this order:
  ///   1. [FirStartEvent] — emitted once with the `case_id` so the UI can
  ///      show the header immediately.
  ///   2. [FirDeltaEvent] — repeated, each carries the next chunk of FIR
  ///      text. Append in order to build the document.
  ///   3. [FirDoneEvent] — terminal event with the assembled full text,
  ///      evidence_id, and any note (e.g. "AI quota exhausted").
  ///   4. [FirErrorEvent] — if the stream failed irrecoverably.
  ///
  /// Errors that happen BEFORE the stream opens (network down, auth failure,
  /// etc.) are thrown synchronously as a [DioException]; subscribe to the
  /// returned stream inside a try/catch around the first iteration.
  Stream<FirStreamEvent> generateFirStream({
    required String incidentType,
    required String description,
    required String incidentDate,
    required String incidentLocation,
    required String complainantName,
    required String complainantPhone,
    String? suspectInfo,
    String? evidenceSummary,
    String? amountLost,
    String? language,
  }) async* {
    final response = await _client.dio.post<ResponseBody>(
      '/video-call/generate-fir-stream',
      data: {
        'incident_type':      incidentType,
        'description':        description,
        'incident_date':      incidentDate,
        'incident_location':  incidentLocation,
        'complainant_name':   complainantName,
        'complainant_phone':  complainantPhone,
        if (suspectInfo     != null) 'suspect_info':     suspectInfo,
        if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
        if (amountLost      != null) 'amount_lost':      amountLost,
        if (language        != null && language.isNotEmpty) 'language': language,
      },
      options: Options(
        responseType:   ResponseType.stream,
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout:    const Duration(seconds: 20),
        headers:        {'Accept': 'text/event-stream'},
      ),
    );

    final stream = response.data!.stream;
    const decoder = Utf8Decoder(allowMalformed: true);
    var buffer = '';

    await for (final chunk in stream) {
      buffer += decoder.convert(chunk);

      // SSE frames are separated by a blank line (\n\n). Parse all
      // complete frames currently in the buffer and leave any partial
      // frame for the next iteration.
      while (true) {
        final sepIdx = buffer.indexOf('\n\n');
        if (sepIdx < 0) break;
        final rawFrame = buffer.substring(0, sepIdx);
        buffer = buffer.substring(sepIdx + 2);

        // A frame is a series of "field: value" lines. We only care about
        // "data:" lines per the SSE spec.
        for (final line in rawFrame.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          try {
            final event = jsonDecode(payload) as Map<String, dynamic>;
            final parsed = FirStreamEvent._parse(event);
            if (parsed != null) yield parsed;
          } catch (_) {
            // Malformed JSON in a single frame — skip and keep streaming.
          }
        }
      }
    }
  }

  Future<Map<String, dynamic>> getPoliceContacts() async {
    final response = await _client.dio.get('/video-call/police-contacts');
    return response.data as Map<String, dynamic>;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sealed-style FIR stream event types
// ─────────────────────────────────────────────────────────────────────────────

abstract class FirStreamEvent {
  const FirStreamEvent();

  /// Try to convert a JSON payload from the SSE wire into a typed event.
  /// Returns null if the payload doesn't match any known event shape.
  static FirStreamEvent? _parse(Map<String, dynamic> json) {
    if (json['started'] == true) {
      return FirStartEvent(caseId: json['case_id'] as String? ?? '');
    }
    if (json['delta'] is String) {
      return FirDeltaEvent(text: json['delta'] as String);
    }
    if (json['complete'] == true || json['done'] == true) {
      return FirDoneEvent(
        firText:    json['fir_draft']  as String?,
        caseId:     json['case_id']    as String?,
        evidenceId: json['evidence_id'] as String?,
        note:       json['note']       as String?,
        error:      json['error']      as String?,
      );
    }
    if (json['error'] != null) {
      return FirErrorEvent(message: json['error'].toString());
    }
    return null;
  }
}

class FirStartEvent extends FirStreamEvent {
  final String caseId;
  const FirStartEvent({required this.caseId});
}

class FirDeltaEvent extends FirStreamEvent {
  final String text;
  const FirDeltaEvent({required this.text});
}

class FirDoneEvent extends FirStreamEvent {
  final String? firText;
  final String? caseId;
  final String? evidenceId;
  final String? note;
  final String? error;
  const FirDoneEvent({this.firText, this.caseId, this.evidenceId, this.note, this.error});
}

class FirErrorEvent extends FirStreamEvent {
  final String message;
  const FirErrorEvent({required this.message});
}

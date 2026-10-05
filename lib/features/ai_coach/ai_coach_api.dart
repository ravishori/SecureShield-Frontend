import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

/// Per-request options used for all AI calls.
///
/// AI generation can take a while — especially when the user has chosen
/// a non-English language (Devanagari / Tamil / Telugu scripts produce
/// 2-3× more tokens per equivalent word, so a 1024-token response can
/// take 30-60s for Hindi/Bengali compared to ~15s for English).
///
/// We override the default 30s receiveTimeout for these endpoints to
/// avoid the user seeing a spurious "unable to respond" fallback while
/// Claude is still legitimately generating.
final _aiRequestOptions = Options(
  receiveTimeout: const Duration(seconds: 90),
  sendTimeout: const Duration(seconds: 30),
);

class AiCoachApi {
  final _client = DioClient();

  /// Send a chat message. [language] is the ISO 639-1 code of the user's
  /// chosen UI language (en/hi/mr/bn/ta/te/…). The backend will instruct
  /// Claude to reply in that language using its native script.
  Future<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
    String? topicCategory,
    String? language,
  }) async {
    final response = await _client.dio.post(
      AppConstants.aiChat,
      data: {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
        if (topicCategory != null) 'topic_category': topicCategory,
        if (language != null && language.isNotEmpty) 'language': language,
      },
      options: _aiRequestOptions,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateComplaintEmail({
    required String incidentType,
    required String description,
    String? evidenceSummary,
    String? suspectInfo,
    String? language,
  }) async {
    final response = await _client.dio.post(
      AppConstants.generateEmail,
      data: {
        'incident_type': incidentType,
        'description': description,
        if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
        if (suspectInfo != null) 'suspect_info': suspectInfo,
        if (language != null && language.isNotEmpty) 'language': language,
      },
      options: _aiRequestOptions,
    );
    return response.data as Map<String, dynamic>;
  }
}

import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class AiCoachApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> chat({
    required String message,
    String? sessionId,
    String? topicCategory,
  }) async {
    final response = await _client.dio.post(
      AppConstants.aiChat,
      data: {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
        if (topicCategory != null) 'topic_category': topicCategory,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateComplaintEmail({
    required String incidentType,
    required String description,
    String? evidenceSummary,
    String? suspectInfo,
  }) async {
    final response = await _client.dio.post(
      AppConstants.generateEmail,
      data: {
        'incident_type': incidentType,
        'description': description,
        if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
        if (suspectInfo != null) 'suspect_info': suspectInfo,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

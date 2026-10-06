import '../../core/constants.dart';
import '../../core/network/dio_client.dart';

class ScamCallsApi {
  final _client = DioClient();

  /// Reports a call the user considers suspicious; the server scores it and may raise an alert.
  Future<Map<String, dynamic>> report({
    required String callerNumber,
    int durationSeconds = 0,
    String? reason,
  }) async {
    final response = await _client.dio.post(
      AppConstants.scamCallReport,
      data: {
        'caller_number': callerNumber,
        'call_duration_seconds': durationSeconds,
        if (reason != null && reason.isNotEmpty) 'detection_reason': reason,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> history() async {
    final response = await _client.dio.get(AppConstants.scamCallHistory);
    return response.data as List<dynamic>;
  }

  Future<void> block(String number) async {
    await _client.dio.post('/scam-calls/block/${Uri.encodeComponent(number)}');
  }
}

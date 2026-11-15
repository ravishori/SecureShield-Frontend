import '../../core/network/dio_client.dart';
import '../../core/constants.dart';
import '../../core/verdict/verdict_response.dart';

class DashboardApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getDailyReport() async {
    final response = await _client.dio.get(AppConstants.dailyReport);
    return response.data as Map<String, dynamic>;
  }

  /// Same request as [getDailyReport], with the additive aggregate verdict (API only; the dashboard UI does not use it yet).
  Future<VerdictResponse> getDailyReportWithVerdict() async => VerdictResponse.from(await getDailyReport());

  Future<List<dynamic>> getRecentAlerts() async {
    final response = await _client.dio.get(
      AppConstants.alerts,
      queryParameters: {'page': 1, 'page_size': 5},
    );
    return response.data['items'] as List<dynamic>;
  }
}

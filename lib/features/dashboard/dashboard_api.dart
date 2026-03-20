import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class DashboardApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getDailyReport() async {
    final response = await _client.dio.get(AppConstants.dailyReport);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getRecentAlerts() async {
    final response = await _client.dio.get(
      AppConstants.alerts,
      queryParameters: {'page': 1, 'page_size': 5},
    );
    return response.data['items'] as List<dynamic>;
  }
}

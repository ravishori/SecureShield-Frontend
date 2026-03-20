import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class ReportsApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getDailyReport() async {
    final response = await _client.dio.get(AppConstants.dailyReport);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _client.dio.get(AppConstants.reportHistory);
    return response.data as List<dynamic>;
  }
}

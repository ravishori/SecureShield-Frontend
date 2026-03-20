import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class AlertsApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getAlerts({int page = 1, int pageSize = 20}) async {
    final response = await _client.dio.get(
      AppConstants.alerts,
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> markRead(String alertId) async {
    await _client.dio.patch('${AppConstants.alerts}/$alertId/read');
  }

  Future<void> dismiss(String alertId) async {
    await _client.dio.patch('${AppConstants.alerts}/$alertId/dismiss');
  }

  Future<void> delete(String alertId) async {
    await _client.dio.delete('${AppConstants.alerts}/$alertId');
  }

  Future<Map<String, dynamic>> triggerPanic({double? lat, double? lon, String? message}) async {
    final response = await _client.dio.post(
      AppConstants.panicAlert,
      data: {
        if (lat != null) 'latitude': lat,
        if (lon != null) 'longitude': lon,
        if (message != null) 'message': message,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class AppScannerApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> scanApps({
    required String deviceId,
    required List<Map<String, dynamic>> apps,
  }) async {
    final response = await _client.dio.post(
      AppConstants.appScan,
      data: {'device_id': deviceId, 'apps': apps},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getResults({String? deviceId}) async {
    final response = await _client.dio.get(
      AppConstants.appScanResults,
      queryParameters: deviceId != null ? {'device_id': deviceId} : null,
    );
    return response.data as List<dynamic>;
  }
}

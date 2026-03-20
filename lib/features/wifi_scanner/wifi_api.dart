import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class WifiApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> scanWifi({
    required String deviceId,
    String? ssid,
    String? bssid,
    int? signalStrength,
    String? encryptionType,
  }) async {
    final response = await _client.dio.post(
      AppConstants.wifiScan,
      data: {
        'device_id': deviceId,
        if (ssid != null) 'ssid': ssid,
        if (bssid != null) 'bssid': bssid,
        if (signalStrength != null) 'signal_strength': signalStrength,
        if (encryptionType != null) 'encryption_type': encryptionType,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _client.dio.get(AppConstants.wifiHistory);
    return response.data as List<dynamic>;
  }
}

import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class LinkScannerApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> scanLink(String url) async {
    final response = await _client.dio.post(
      AppConstants.linkScan,
      data: {'url': url},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getHistory() async {
    final response = await _client.dio.get(AppConstants.linkHistory);
    return response.data as List<dynamic>;
  }
}

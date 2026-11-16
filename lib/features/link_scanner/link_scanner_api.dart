import '../../core/network/dio_client.dart';
import '../../core/constants.dart';
import '../../core/verdict/verdict_response.dart';

class LinkScannerApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> scanLink(String url) async {
    final response = await _client.dio.post(
      AppConstants.linkScan,
      data: {'url': url},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Same request as [scanLink], with the additive shared verdict parsed (null if absent or malformed).
  Future<VerdictResponse> scanLinkWithVerdict(String url) async => VerdictResponse.from(await scanLink(url));

  /// Same request as [getHistory], each item with its optional shared verdict.
  Future<List<VerdictResponse>> getHistoryWithVerdicts() async => VerdictResponse.listFrom(await getHistory());

  Future<List<dynamic>> getHistory() async {
    final response = await _client.dio.get(AppConstants.linkHistory);
    return response.data as List<dynamic>;
  }
}

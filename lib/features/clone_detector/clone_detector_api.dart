import '../../core/network/dio_client.dart';
import 'models/clone_result.dart';

class CloneDetectorApi {
  final _client = DioClient();

  Future<CloneResult?> scanApp({
    required String packageName,
    required String appName,
    String? certHash,
  }) async {
    try {
      final resp = await _client.dio.post('/clone-detection/scan', data: {
        'package_name': packageName,
        'app_name':     appName,
        if (certHash != null) 'cert_hash': certHash,
      });
      return CloneResult.fromJson(resp.data as Map<String, dynamic>);
    } catch (_) { return null; }
  }

  Future<List<CloneResult>> fetchHistory({String? verdict}) async {
    try {
      final resp = await _client.dio.get('/clone-detection/history',
          queryParameters: {if (verdict != null) 'verdict': verdict});
      final list = (resp.data['reports'] as List?) ?? [];
      return list.map((e) => CloneResult.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  Future<bool> submitFeedback({
    required String reportId,
    required bool userConfirmed,
    String? actionTaken,
  }) async {
    try {
      await _client.dio.post('/clone-detection/feedback', data: {
        'report_id':      reportId,
        'user_confirmed': userConfirmed,
        if (actionTaken != null) 'action_taken': actionTaken,
      });
      return true;
    } catch (_) { return false; }
  }

  Future<List<Map<String, dynamic>>> fetchCatalogue() async {
    try {
      final resp = await _client.dio.get('/clone-detection/catalogue');
      return ((resp.data['apps'] as List?) ?? [])
          .map((e) => e as Map<String, dynamic>).toList();
    } catch (_) { return []; }
  }
}

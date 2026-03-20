import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class EvidenceApi {
  final _client = DioClient();

  Future<List<dynamic>> getEvidence() async {
    final response = await _client.dio.get(AppConstants.evidence);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> uploadEvidence({
    required String title,
    String? description,
    String? caseId,
    required String filePath,
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      if (description != null) 'description': description,
      if (caseId != null) 'case_id': caseId,
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _client.dio.post(
      AppConstants.evidenceUpload,
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> delete(String id) async {
    await _client.dio.delete('${AppConstants.evidence}/$id');
  }
}

import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/verdict/verdict_response.dart';

class MessageAnalyzerApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> analyzeMessage({
    required String messageText,
    String? sender,
    bool useAi = true,
  }) async {
    final response = await _client.dio.post('/message/analyze', data: {
      'message_text': messageText,
      if (sender != null && sender.isNotEmpty) 'sender': sender,
      'use_ai': useAi,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Same request as [analyzeMessage], with the additive shared verdict parsed (null if absent or malformed).
  Future<VerdictResponse> analyzeMessageWithVerdict({
    required String messageText,
    String? sender,
    bool useAi = true,
  }) async =>
      VerdictResponse.from(await analyzeMessage(messageText: messageText, sender: sender, useAi: useAi));

  /// Same request as [checkJobOffer], with the additive shared verdict parsed (null if absent or malformed).
  Future<VerdictResponse> checkJobOfferWithVerdict({required String jobText, bool useAi = true}) async =>
      VerdictResponse.from(await checkJobOffer(jobText: jobText, useAi: useAi));

  Future<Map<String, dynamic>> checkJobOffer({
    required String jobText,
    bool useAi = true,
  }) async {
    final response = await _client.dio.post('/message/check-job-offer', data: {
      'job_text': jobText,
      'use_ai': useAi,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkBullying({
    required String messageText,
    String? reporterNote,
  }) async {
    final response = await _client.dio.post('/message/check-bullying', data: {
      'message_text': messageText,
      if (reporterNote != null) 'reporter_note': reporterNote,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Upload an SMS screenshot. Returns extracted sender, message text, phone number.
  Future<Map<String, dynamic>> extractFromScreenshot(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.path.split('/').last,
      ),
    });
    final response = await _client.dio.post(
      '/message/extract-screenshot',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data as Map<String, dynamic>;
  }

  /// Validate a single sender ID against the TRAI registry.
  Future<Map<String, dynamic>> validateSender(String sender) async {
    final response = await _client.dio.post(
      '/message/validate-sender',
      data: {'sender': sender},
    );
    return response.data as Map<String, dynamic>;
  }
}

import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class OtpVaultApi {
  final _client = DioClient();

  Future<List<dynamic>> getEntries() async {
    final response = await _client.dio.get(AppConstants.otpVaultEntries);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addEntry({
    String? sender,
    String? rawOtp,
    required String encryptedContent,
    String? sourceApp,
  }) async {
    final response = await _client.dio.post(
      AppConstants.otpVaultEntries,
      data: {
        if (sender != null) 'sender': sender,
        if (rawOtp != null) 'raw_otp': rawOtp,
        'encrypted_content': encryptedContent,
        if (sourceApp != null) 'source_app': sourceApp,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> markRead(String entryId) async {
    await _client.dio.patch('${AppConstants.otpVaultEntries}/$entryId/read');
  }

  Future<void> delete(String entryId) async {
    await _client.dio.delete('${AppConstants.otpVaultEntries}/$entryId');
  }
}

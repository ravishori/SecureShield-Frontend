import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class UserApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> getMe() async {
    final response = await _client.dio.get(AppConstants.getMe);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? fullName,
    String? email,
    bool? seniorMode,
  }) async {
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (email != null) data['email'] = email;
    if (seniorMode != null) data['senior_mode'] = seniorMode;

    final response = await _client.dio.patch(AppConstants.updateMe, data: data);
    return response.data as Map<String, dynamic>;
  }
}

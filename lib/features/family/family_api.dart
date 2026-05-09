import '../../core/network/dio_client.dart';
import '../../core/constants.dart';

class FamilyApi {
  final _client = DioClient();

  Future<List<dynamic>> getMembers() async {
    final response = await _client.dio.get(AppConstants.familyMembers);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addMember({
    String? memberPhone,
    String? relationship,
    String? nickname,
    bool canViewAlerts = false,
    bool canTriggerPanic = false,
    bool isChildProfile = false,
    bool contentFilterEnabled = false,
    bool cyberbullyingAlerts = false,
  }) async {
    final response = await _client.dio.post(
      AppConstants.familyMembers,
      data: {
        if (memberPhone != null) 'member_phone': memberPhone,
        if (relationship != null) 'relationship': relationship,
        if (nickname != null) 'nickname': nickname,
        'can_view_alerts': canViewAlerts,
        'can_trigger_panic': canTriggerPanic,
        'is_child_profile': isChildProfile,
        'content_filter_enabled': contentFilterEnabled,
        'cyberbullying_alerts': cyberbullyingAlerts,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String memberId) async {
    await _client.dio.delete('${AppConstants.familyMembers}/$memberId');
  }
}

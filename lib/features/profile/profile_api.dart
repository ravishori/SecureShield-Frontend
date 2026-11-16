import '../../core/network/dio_client.dart';

class ProfileApi {
  final _client = DioClient();

  // ── Emergency Contacts ───────────────────────────────────────────────────

  Future<List<dynamic>> getEmergencyContacts() async {
    final res = await _client.dio.get('/emergency-contacts');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    String? relationship,
    String? phone,
    String? email,
  }) async {
    final res = await _client.dio.post('/emergency-contacts', data: {
      'name': name,
      if (relationship != null && relationship.isNotEmpty) 'relationship': relationship,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return res.data as Map<String, dynamic>;
  }

  /// Partial update — null / absent fields leave their existing values
  /// alone. To clear a field, pass an empty string.
  Future<Map<String, dynamic>> updateEmergencyContact({
    required String id,
    String? name,
    String? relationship,
    String? phone,
    String? email,
  }) async {
    final res = await _client.dio.patch('/emergency-contacts/$id', data: {
      if (name != null) 'name': name,
      if (relationship != null) 'relationship': relationship,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteEmergencyContact(String id) async {
    await _client.dio.delete('/emergency-contacts/$id');
  }
}

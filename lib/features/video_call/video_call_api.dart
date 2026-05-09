import '../../core/network/dio_client.dart';

class VideoCallApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> createRoom({
    String callType = 'police_report',
    String? incidentType,
    String? notes,
  }) async {
    final response = await _client.dio.post('/video-call/create-room', data: {
      'call_type': callType,
      if (incidentType != null) 'incident_type': incidentType,
      if (notes != null) 'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateFir({
    required String incidentType,
    required String description,
    required String incidentDate,
    required String incidentLocation,
    required String complainantName,
    required String complainantPhone,
    String? suspectInfo,
    String? evidenceSummary,
    String? amountLost,
  }) async {
    final response = await _client.dio.post('/video-call/generate-fir', data: {
      'incident_type': incidentType,
      'description': description,
      'incident_date': incidentDate,
      'incident_location': incidentLocation,
      'complainant_name': complainantName,
      'complainant_phone': complainantPhone,
      if (suspectInfo != null) 'suspect_info': suspectInfo,
      if (evidenceSummary != null) 'evidence_summary': evidenceSummary,
      if (amountLost != null) 'amount_lost': amountLost,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPoliceContacts() async {
    final response = await _client.dio.get('/video-call/police-contacts');
    return response.data as Map<String, dynamic>;
  }
}

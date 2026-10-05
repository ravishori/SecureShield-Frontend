import '../../core/network/dio_client.dart';

class CommunityScamApi {
  final _client = DioClient();

  Future<Map<String, dynamic>> reportScam({
    required String scamType,
    required String title,
    required String description,
    String? phoneNumber,
    String? url,
    String? city,
    String? pincode,
  }) async {
    final response = await _client.dio.post('/community-scams/report', data: {
      'scam_type': scamType,
      'title': title,
      'description': description,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (url != null) 'url': url,
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getFeed({String? city, String? pincode, String? scamType}) async {
    final response = await _client.dio.get('/community-scams/feed', queryParameters: {
      if (city != null) 'city': city,
      if (pincode != null) 'pincode': pincode,
      if (scamType != null) 'scam_type': scamType,
    });
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getTrending({String? city}) async {
    final response = await _client.dio.get('/community-scams/trending', queryParameters: {
      if (city != null) 'city': city,
    });
    return response.data as List<dynamic>;
  }

  Future<void> upvote(String reportId) async {
    await _client.dio.post('/community-scams/$reportId/upvote');
  }

  Future<Map<String, dynamic>> getScamNewsFeed({String? city}) async {
    final response = await _client.dio.get(
      '/community-scams/news-feed',
      queryParameters: {if (city != null) 'city': city},
    );
    return response.data as Map<String, dynamic>;
  }
}

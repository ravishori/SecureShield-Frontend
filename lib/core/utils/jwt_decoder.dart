import 'dart:convert';

class JwtDecoder {
  static Map<String, dynamic> decode(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return {};
    try {
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  static String? getUserId(String token) {
    return decode(token)['sub'] as String?;
  }

  /// Returns the login identifier — checks 'identifier' first,
  /// then falls back to 'phone' or 'email' for backwards compatibility.
  static String? getIdentifier(String token) {
    final payload = decode(token);
    return (payload['identifier'] ?? payload['phone'] ?? payload['email']) as String?;
  }

  /// Legacy helper — returns phone if it was used as identifier.
  static String? getPhone(String token) {
    final payload = decode(token);
    final id = (payload['identifier'] ?? payload['phone']) as String?;
    if (id != null && !id.contains('@')) return id;
    return null;
  }

  /// Returns email if it was used as identifier.
  static String? getEmail(String token) {
    final payload = decode(token);
    final id = (payload['identifier'] ?? payload['email']) as String?;
    if (id != null && id.contains('@')) return id;
    return null;
  }

  static bool isExpired(String token) {
    final payload = decode(token);
    final exp = payload['exp'];
    if (exp == null) return true;
    final expDate = DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    return DateTime.now().isAfter(expDate);
  }
}

import 'scam_verdict.dart';

/// A server response kept exactly as received (`body`, for the existing screens) plus its optional shared verdict.
///
/// The verdict is additive: an older server, a missing key or a malformed verdict give `verdict == null` and the caller
/// keeps using the old fields. A bad verdict is never turned into a `safe` one.
class VerdictResponse {
  final Map<String, dynamic> body;
  final ScamVerdict? verdict;

  const VerdictResponse(this.body, this.verdict);

  factory VerdictResponse.from(Object? body) {
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    return VerdictResponse(map, ScamVerdict.tryParse(map['verdict']));
  }

  static List<VerdictResponse> listFrom(Object? body) =>
      body is List ? body.map(VerdictResponse.from).toList() : const <VerdictResponse>[];
}

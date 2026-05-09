/// Pure-Dart string similarity metrics for fake/clone-app detection.
///
/// All algorithms run fully offline and are pure functions — no I/O, no state.
/// Production use: feed two normalized labels (or package-id segments) and
/// compare the result against a per-metric threshold.
///
/// Performance:
///  • Levenshtein is O(m·n) memory and time. We cap inputs at 64 chars to keep
///    memory < 8 KB per call. Anything longer is virtually never an app label.
///  • Jaro-Winkler runs in O(m·n) but with negligible constants for short
///    inputs. It is the recommended default for fake-app detection because
///    it weights common prefixes (humans phishing usually keep the brand
///    prefix intact: WhatsApp → WhaatsApp).
library;

class SimilarityMetrics {
  SimilarityMetrics._();

  /// Strip non-alphanumeric, lowercase. Devanagari is preserved because Indian
  /// app labels often mix scripts (e.g. "एसबीआई SBI").
  /// "WhatsApp™ — Free messaging" → "whatsappfreemessaging"
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    for (final r in lower.runes) {
      if ((r >= 0x30 && r <= 0x39)            // 0–9
          || (r >= 0x61 && r <= 0x7A)         // a–z
          || (r >= 0x0900 && r <= 0x097F)) {  // Devanagari
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  /// Levenshtein edit distance — fewer edits = more similar.
  /// If [maxDistance] is supplied, returns `maxDistance + 1` early when the
  /// minimum possible distance already exceeds the cap.
  static int levenshtein(String a, String b, {int maxDistance = 1 << 30}) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    if (a.length > 64) a = a.substring(0, 64);
    if (b.length > 64) b = b.substring(0, 64);

    final m = a.length, n = b.length;
    if ((m - n).abs() > maxDistance) return maxDistance + 1;

    // Two-row DP. `prev[j]` = distance for previous source-prefix.
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      var rowMin = i;
      final aChar = a.codeUnitAt(i - 1);
      for (var j = 1; j <= n; j++) {
        final cost = aChar == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        var v = del < ins ? del : ins;
        if (sub < v) v = sub;
        curr[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > maxDistance) return maxDistance + 1;

      // Swap rows: previous becomes the just-computed, current becomes scratch.
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  /// Normalized similarity in [0,1] derived from Levenshtein distance.
  /// 1.0 = identical, 0.0 = totally different.
  static double levenshteinSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen == 0) return 1.0;
    return 1.0 - (levenshtein(a, b) / maxLen);
  }

  /// Jaro similarity in [0,1]. Pre-step for Jaro-Winkler.
  static double jaro(String a, String b) {
    if (a == b) return 1.0;
    final m = a.length, n = b.length;
    if (m == 0 || n == 0) return 0.0;

    final matchWindow = ((m > n ? m : n) ~/ 2) - 1;
    if (matchWindow < 0) return a == b ? 1.0 : 0.0;

    final aMatches = List<bool>.filled(m, false);
    final bMatches = List<bool>.filled(n, false);
    var matches = 0;

    for (var i = 0; i < m; i++) {
      final lo = (i - matchWindow) > 0 ? (i - matchWindow) : 0;
      final hi = (i + matchWindow + 1) < n ? (i + matchWindow + 1) : n;
      for (var j = lo; j < hi; j++) {
        if (bMatches[j]) continue;
        if (a.codeUnitAt(i) != b.codeUnitAt(j)) continue;
        aMatches[i] = true;
        bMatches[j] = true;
        matches++;
        break;
      }
    }
    if (matches == 0) return 0.0;

    var transpositions = 0, k = 0;
    for (var i = 0; i < m; i++) {
      if (!aMatches[i]) continue;
      while (!bMatches[k]) {
        k++;
      }
      if (a.codeUnitAt(i) != b.codeUnitAt(k)) transpositions++;
      k++;
    }
    transpositions ~/= 2;

    final md = matches.toDouble();
    return ((md / m) + (md / n) + ((md - transpositions) / md)) / 3.0;
  }

  /// Jaro-Winkler similarity. Boosts score when strings share a common prefix —
  /// catches "WhatsApp" vs "WhaatsApp", "PhonePe" vs "PhoonePe".
  /// Range [0,1]; ≥ 0.92 = strong impersonation suspicion.
  static double jaroWinkler(String a, String b, {double prefixScale = 0.1}) {
    final j = jaro(a, b);
    if (j < 0.7) return j; // standard practice: skip the boost for low Jaro
    final prefixLen = _commonPrefix(a, b, max: 4);
    return j + (prefixLen * prefixScale * (1 - j));
  }

  static int _commonPrefix(String a, String b, {int max = 4}) {
    final n = a.length < b.length ? a.length : b.length;
    final cap = n < max ? n : max;
    var i = 0;
    while (i < cap && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  /// Confusable-character fold — collapses homoglyph swaps scammers use to
  /// dodge exact match: SBI vs SBl (capital I → l), 0/o, 1/l/i, 5/s, 3/e.
  /// Apply BEFORE jaroWinkler when checking against a known brand.
  static String foldConfusables(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      switch (r) {
        case 0x30: sb.writeCharCode(0x6F); break; // 0 → o
        case 0x31:                                 // 1 → l
        case 0x69: sb.writeCharCode(0x6C); break; // i → l
        case 0x35: sb.writeCharCode(0x73); break; // 5 → s
        case 0x33: sb.writeCharCode(0x65); break; // 3 → e
        default:   sb.writeCharCode(r);
      }
    }
    return sb.toString();
  }
}

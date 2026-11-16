import 'package:flutter_test/flutter_test.dart';
import 'package:secureshield_app/core/security/similarity_metrics.dart';

/// Similarity metrics are the first line of fake-app detection
/// (WhatsApp vs WhaatsApp, Paytm vs Paytmm). A silent regression here
/// means impersonating apps slip through, so we lock the behaviour down.
void main() {
  group('normalize', () {
    test('lowercases and strips non-alphanumeric', () {
      expect(SimilarityMetrics.normalize('WhatsApp Messenger'),
          'whatsappmessenger');
    });

    test('preserves Devanagari (Hindi script)', () {
      // Indian app labels frequently mix scripts
      expect(SimilarityMetrics.normalize('एसबीआई SBI'),
          contains('एसबीआई'));
      expect(SimilarityMetrics.normalize('एसबीआई SBI'),
          contains('sbi'));
    });

    test('empty input returns empty', () {
      expect(SimilarityMetrics.normalize(''), '');
    });
  });

  group('levenshtein', () {
    test('identical strings have distance 0', () {
      expect(SimilarityMetrics.levenshtein('whatsapp', 'whatsapp'), 0);
    });

    test('single character difference has distance 1', () {
      expect(SimilarityMetrics.levenshtein('paytm', 'paytmm'), 1);
    });

    test('WhatsApp vs WhaatsApp = 1 insertion', () {
      // Real-world fake-app pattern
      expect(SimilarityMetrics.levenshtein('whatsapp', 'whaatsapp'), 1);
    });

    test('empty vs non-empty equals the length', () {
      expect(SimilarityMetrics.levenshtein('', 'abc'), 3);
      expect(SimilarityMetrics.levenshtein('abc', ''), 3);
    });

    test('respects maxDistance cap for early exit', () {
      // When cap is clearly too low, result exceeds cap+1
      final d = SimilarityMetrics.levenshtein(
          'completely_different', 'xyz', maxDistance: 2);
      expect(d, greaterThan(2),
          reason: 'With cap=2, far-apart strings should bail early');
    });
  });

  group('jaroWinkler', () {
    test('identical strings score 1.0', () {
      expect(SimilarityMetrics.jaroWinkler('paytm', 'paytm'),
          closeTo(1.0, 1e-9));
    });

    test('impersonators score high due to shared prefix', () {
      // Scammers keep the brand prefix intact to look legit
      final s = SimilarityMetrics.jaroWinkler('whatsapp', 'whaatsapp');
      expect(s, greaterThan(0.92),
          reason: 'Prefix-matching impersonators must trigger detection '
                  'thresholds (≥ 0.92)');
    });

    test('unrelated strings score low', () {
      final s = SimilarityMetrics.jaroWinkler('whatsapp', 'calendar');
      expect(s, lessThan(0.7));
    });

    test('empty vs non-empty is 0', () {
      expect(SimilarityMetrics.jaroWinkler('', 'anything'), 0.0);
    });

    test('SBI vs SBl (capital-I/lowercase-l homoglyph)', () {
      // Common bank-impersonation trick — must still score very high
      // once confusables are folded.
      final folded = SimilarityMetrics.foldConfusables('sbi');
      final foldedAttack = SimilarityMetrics.foldConfusables('sbl');
      final s = SimilarityMetrics.jaroWinkler(folded, foldedAttack);
      expect(s, greaterThan(0.9),
          reason: 'Confusable fold must bring SBI and SBl into the same '
                  'similarity bucket');
    });
  });

  group('foldConfusables', () {
    test('folds digit-to-letter homoglyphs', () {
      // 0→o, 1→l, i→l, 5→s, 3→e
      expect(SimilarityMetrics.foldConfusables('p0ytm'), 'poytm');
      expect(SimilarityMetrics.foldConfusables('b1ngo'), 'blngo');
      expect(SimilarityMetrics.foldConfusables('sb1'), 'sbl');
      expect(SimilarityMetrics.foldConfusables('5bi'), 'sbl'); // 5→s, i→l
    });

    test('leaves normal letters untouched', () {
      expect(SimilarityMetrics.foldConfusables('whatsapp'), 'whatsapp');
    });
  });

  group('levenshteinSimilarity', () {
    test('bounded in [0,1]', () {
      final s = SimilarityMetrics.levenshteinSimilarity('abc', 'xyz');
      expect(s, inInclusiveRange(0.0, 1.0));
    });

    test('identical = 1', () {
      expect(SimilarityMetrics.levenshteinSimilarity('x', 'x'), 1.0);
    });

    test('both empty = 1 (edge case)', () {
      expect(SimilarityMetrics.levenshteinSimilarity('', ''), 1.0);
    });
  });
}

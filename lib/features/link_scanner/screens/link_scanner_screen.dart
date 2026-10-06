import 'package:secureshield_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../link_scanner_api.dart';

class LinkScannerScreen extends StatefulWidget {
  const LinkScannerScreen({super.key});

  @override
  State<LinkScannerScreen> createState() => _LinkScannerScreenState();
}

class _LinkScannerScreenState extends State<LinkScannerScreen> {
  final _api = LinkScannerApi();
  final _urlController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _scanning = false;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _api.getHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {}
  }

  Future<void> _scan() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).lsEnterUrl)),
      );
      return;
    }
    setState(() {
      _scanning = true;
      _result = null;
    });
    try {
      final result = await _api.scanLink(url);
      if (mounted) {
        setState(() {
          _result = result;
          _scanning = false;
        });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).lsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────
            _InfoBanner(),
            const SizedBox(height: 16),

            // ── URL input ──────────────────────────────────────────────
            TextField(
              controller: _urlController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).lsEnterToScan,
                hintText: 'https://example.com',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _urlController.clear();
                          setState(() => _result = null);
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: _scanning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.security),
                label: Text(_scanning ? 'Scanning...' : 'Scan URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Scan result ────────────────────────────────────────────
            if (_result != null) _ScanResultCard(result: _result!),

            // ── History ────────────────────────────────────────────────
            if (_history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).lsRecent,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              ..._history.take(10).map((h) => _HistoryTile(item: h as Map<String, dynamic>)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info Banner ────────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined, color: cs.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Powered by Google Safe Browsing — checks URLs against known malware, phishing, and scam databases.',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan Result Card ───────────────────────────────────────────────────────────
class _ScanResultCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _ScanResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isMalicious = result['is_malicious'] as bool? ?? false;
    final isPhishing = result['is_phishing'] as bool? ?? false;
    final riskScore = (result['risk_score'] as num?)?.toDouble() ?? 0.0;
    final threatCategory = result['threat_category'] as String? ?? '';
    final scanProvider = result['scan_provider'] as String? ?? 'internal';
    final gsb = result['gsb_threats'] as List<dynamic>?;
    final url = result['url'] as String? ?? '';

    // The backend reports "google_safe_browsing+urlhaus" when both providers answered.
    final isGsbVerified = scanProvider.contains('google_safe_browsing');
    // Show the "unable to fully verify" banner ONLY when no live external
    // provider could be consulted (true internal-only path).
    final isFallback = scanProvider == 'internal_fallback';
    final isHybrid = scanProvider == 'hybrid_fallback';
    final isSuspicious = !isMalicious && (isPhishing || (riskScore >= 30 && riskScore < 60));

    // Determine tier
    final _Tier tier;
    if (isMalicious) {
      tier = _Tier.malicious;
    } else if (isSuspicious || riskScore >= 30) {
      tier = _Tier.suspicious;
    } else {
      tier = _Tier.safe;
    }

    final color = switch (tier) {
      _Tier.safe => AppTheme.success,
      _Tier.suspicious => AppTheme.warning,
      _Tier.malicious => AppTheme.errorColor,
    };
    final icon = switch (tier) {
      _Tier.safe => Icons.verified_user,
      _Tier.suspicious => Icons.warning_amber_rounded,
      _Tier.malicious => Icons.gpp_bad,
    };
    final label = switch (tier) {
      _Tier.safe => 'SAFE',
      _Tier.suspicious => 'SUSPICIOUS',
      _Tier.malicious => 'MALICIOUS',
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              children: [
                Icon(icon, size: 60, color: color),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                // Risk score bar
                _RiskScoreBar(score: riskScore, color: color),
                const SizedBox(height: 8),
                // Provider badge
                _ProviderBadge(scanProvider: scanProvider, isGsbVerified: isGsbVerified),
              ],
            ),
          ),

          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),

          // ── URL row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.link, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    url.length > 60 ? '${url.substring(0, 60)}…' : url,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context).lsCopied), duration: const Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── GSB threat details (when confirmed threats) ──────────────
          if (isGsbVerified && gsb != null && gsb.isNotEmpty) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield, size: 14, color: AppTheme.errorColor),
                      SizedBox(width: 6),
                      Text(
                        'Google Safe Browsing Threats',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...gsb.map((t) {
                    final threat = t as Map<String, dynamic>;
                    final label = threat['threat_label'] as String? ??
                        threat['threat_type'] as String? ?? 'Unknown Threat';
                    final threatType = threat['threat_type'] as String? ?? '';
                    final threatIcon = _threatIcon(threatType);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(threatIcon, style: const TextStyle(fontSize: 14)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _threatDescription(threatType),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // ── Threat category chip (non-GSB threats) ───────────────────
          if (threatCategory.isNotEmpty && !(isGsbVerified && gsb != null && gsb.isNotEmpty)) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(
                      threatCategory.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: color.withValues(alpha: 0.12),
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
              ),
            ),
          ],

          // ── Fallback caution message ──────────────────────────────────
          // Only shown when NO live external provider could be reached.
          // URLhaus-verified or hybrid scans skip this and show their own
          // provider badge instead.
          if (isFallback || isHybrid) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isFallback
                          ? 'Live threat feeds were unreachable — this result is based on '
                            'internal phishing heuristics only. Proceed with caution.'
                          : 'Google Safe Browsing is temporarily unreachable. Verified '
                            'against URLhaus + internal heuristics instead.',
                      style: const TextStyle(
                        color: AppTheme.warning,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Action advice ─────────────────────────────────────────────
          if (tier != _Tier.safe) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _ActionAdvice(tier: tier, isMalicious: isMalicious, isPhishing: isPhishing),
            ),
          ],
        ],
      ),
    );
  }

  String _threatIcon(String type) => switch (type) {
        'MALWARE' => '🦠',
        'SOCIAL_ENGINEERING' => '🎣',
        'UNWANTED_SOFTWARE' => '⚠️',
        'POTENTIALLY_HARMFUL_APPLICATION' => '📱',
        _ => '🚨',
      };

  String _threatDescription(String type) => switch (type) {
        'MALWARE' =>
          'This URL may install harmful software that damages or steals data from your device.',
        'SOCIAL_ENGINEERING' =>
          'This page tries to deceive you into sharing personal info or credentials.',
        'UNWANTED_SOFTWARE' =>
          'This URL may lead to software that behaves in unexpected or unwanted ways.',
        'POTENTIALLY_HARMFUL_APPLICATION' =>
          'This URL may be associated with apps that violate safety policies.',
        _ => 'This URL was flagged by Google Safe Browsing as dangerous.',
      };
}

enum _Tier { safe, suspicious, malicious }

// ── Risk Score Bar ─────────────────────────────────────────────────────────────
class _RiskScoreBar extends StatelessWidget {
  final double score;
  final Color color;
  const _RiskScoreBar({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context).lsRisk,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${score.toStringAsFixed(0)} / 100',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 7,
          ),
        ),
      ],
    );
  }
}

// ── Provider Badge ─────────────────────────────────────────────────────────────
class _ProviderBadge extends StatelessWidget {
  final String scanProvider;
  final bool isGsbVerified;
  const _ProviderBadge({required this.scanProvider, required this.isGsbVerified});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (scanProvider) {
      'google_safe_browsing' => (
          'Verified by Google Safe Browsing',
          Icons.verified,
          theme.primary,
        ),
      'google_safe_browsing+urlhaus' => (
          'Verified by Google Safe Browsing + URLhaus',
          Icons.verified,
          theme.primary,
        ),
      'urlhaus' => (
          'Verified by URLhaus (abuse.ch)',
          Icons.verified_user,
          theme.primary,
        ),
      'urlhaus_clean_internal_score' => (
          'Checked via URLhaus + internal rules',
          Icons.fact_check_outlined,
          theme.primary,
        ),
      'hybrid_fallback' => (
          'URLhaus + internal rules (GSB temporarily unreachable)',
          Icons.shield_outlined,
          const Color(0xFFFF8800),
        ),
      'internal_fallback' => (
          'Internal heuristics only (no live threat feed)',
          Icons.warning_amber_rounded,
          const Color(0xFFFF8800),
        ),
      _ => ('Internal scan', Icons.security, theme.onSurfaceVariant),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// ── Action Advice ──────────────────────────────────────────────────────────────
class _ActionAdvice extends StatelessWidget {
  final _Tier tier;
  final bool isMalicious;
  final bool isPhishing;
  const _ActionAdvice({required this.tier, required this.isMalicious, required this.isPhishing});

  @override
  Widget build(BuildContext context) {
    final (title, body, icon, color) = switch (tier) {
      _Tier.malicious => (
          'Do NOT open this URL',
          isMalicious && !isPhishing
              ? 'This URL is flagged as malware. It may install viruses, ransomware, or spyware on your device. Do not visit, share, or click this link.'
              : 'This is a phishing page designed to steal your passwords, OTPs, or banking credentials. Do not enter any information.',
          Icons.block,
          AppTheme.errorColor,
        ),
      _Tier.suspicious => (
          'Proceed with caution',
          'This URL shows suspicious characteristics. Verify the source before opening. Never enter personal information on unknown websites.',
          Icons.warning_amber,
          AppTheme.warning,
        ),
      _Tier.safe => ('', '', Icons.check, AppTheme.success),
    };

    if (tier == _Tier.safe) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        if (tier == _Tier.malicious) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL blocked — do not visit this site'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              },
              icon: const Icon(Icons.report, size: 16),
              label: const Text('Block & Dismiss', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── History Tile ───────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final isMalicious = item['is_malicious'] as bool? ?? false;
    final isPhishing  = item['is_phishing']  as bool? ?? false;
    final riskScore   = (item['risk_score'] as num?)?.toDouble() ?? 0.0;
    final url         = item['url']           as String? ?? '';
    final provider    = item['scan_provider'] as String? ?? 'internal';
    final gsb         = item['gsb_threats']   as List<dynamic>?;

    final isSuspicious = !isMalicious && (isPhishing || riskScore >= 30);

    // Risk-tier palette — pulls from the live theme so light/dark both work.
    final tierColor = isMalicious
        ? const Color(0xFFB00020)
        : isSuspicious
            ? const Color(0xFFFF6D00)
            : const Color(0xFF2E7D32);

    final statusLabel = isMalicious
        ? 'MALICIOUS'
        : isSuspicious
            ? 'SUSPICIOUS'
            : 'SAFE';

    final hasGsbThreats = gsb != null && gsb.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: tierColor.withValues(alpha: 0.5)),
            ),
            child: Icon(
              isMalicious
                  ? Icons.gpp_bad_rounded
                  : isSuspicious
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
              color: tierColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url.length > 45 ? '${url.substring(0, 45)}…' : url,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (provider == 'google_safe_browsing') ...[
                      Icon(Icons.verified, size: 12, color: cs.primary),
                      const SizedBox(width: 3),
                      Text('GSB',
                          style: TextStyle(
                              color: cs.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                    ] else if (provider == 'internal_fallback') ...[
                      const Icon(Icons.warning_amber_rounded,
                          size: 12, color: Color(0xFFFF8800)),
                      const SizedBox(width: 3),
                      const Text('Fallback',
                          style: TextStyle(
                              color: Color(0xFFFF8800),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 8),
                    ],
                    if (hasGsbThreats) ...[
                      Text('•',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11)),
                      const SizedBox(width: 6),
                      Text(
                        '${gsb.length} threat${gsb.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Color(0xFFB00020),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${riskScore.toStringAsFixed(0)}/100',
                style: TextStyle(
                  color: tierColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CloneResult {
  final String id;
  final String packageName;
  final String appName;
  final String? targetPackage;
  final String? targetName;
  final int nameSimilarity;       // 0-100
  final int packageSimilarity;    // 0-100
  final int overallScore;         // 0-100
  final String verdict;           // safe / suspicious / likely_clone / confirmed_clone
  final List<String> signals;
  final String actionRecommended; // none / warn / block / uninstall
  final DateTime createdAt;

  const CloneResult({
    required this.id,
    required this.packageName,
    required this.appName,
    this.targetPackage,
    this.targetName,
    required this.nameSimilarity,
    required this.packageSimilarity,
    required this.overallScore,
    required this.verdict,
    required this.signals,
    required this.actionRecommended,
    required this.createdAt,
  });

  factory CloneResult.fromJson(Map<String, dynamic> j) => CloneResult(
    id:                  j['id']?.toString()                    ?? '',
    packageName:         j['package_name']?.toString()          ?? '',
    appName:             j['app_name']?.toString()              ?? '',
    targetPackage:       j['target_package']?.toString(),
    targetName:          j['target_name']?.toString(),
    nameSimilarity:      (j['name_similarity'] as num?)?.toInt()    ?? 0,
    packageSimilarity:   (j['package_similarity'] as num?)?.toInt() ?? 0,
    overallScore:        (j['overall_score'] as num?)?.toInt()      ?? 0,
    verdict:             j['verdict']?.toString()               ?? 'safe',
    signals:             (j['signals'] as List?)?.map((e) => e.toString()).toList() ?? [],
    actionRecommended:   j['action_recommended']?.toString()    ?? 'none',
    createdAt: j['created_at'] != null
        ? DateTime.tryParse(j['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );

  bool get isSafe     => verdict == 'safe';
  bool get isClone    => verdict == 'likely_clone' || verdict == 'confirmed_clone';

  String get verdictLabel => switch (verdict) {
    'confirmed_clone' => 'CONFIRMED FAKE',
    'likely_clone'    => 'LIKELY FAKE',
    'suspicious'      => 'SUSPICIOUS',
    _                 => 'SAFE',
  };
}

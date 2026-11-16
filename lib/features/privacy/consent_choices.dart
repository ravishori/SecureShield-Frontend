/// What the person agreed to on the consent screen. The two acknowledgements are always true here (the screen cannot be passed
/// without them); [aiProcessing] is a separate, optional choice that defaults to "no".
class ConsentChoices {
  final String termsVersion;
  final String privacyVersion;
  final bool aiProcessing;
  const ConsentChoices({
    required this.termsVersion,
    required this.privacyVersion,
    required this.aiProcessing,
  });

  /// Request body fragment understood by the backend (`consent` field of register / Google sign-in).
  Map<String, dynamic> toJson() => {
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
        'ai_processing': aiProcessing,
      };
}

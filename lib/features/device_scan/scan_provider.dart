import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set to true once per app session after the user completes (or skips) the
/// device scan. Router uses this to avoid re-scanning on every navigation.
final deviceScanDoneProvider = StateProvider<bool>((ref) => false);

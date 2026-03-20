// Add to MainActivity.kt in android/app/src/main/kotlin/.../MainActivity.kt:
// override fun onCreate(savedInstanceState: Bundle?) {
//     super.onCreate(savedInstanceState)
//     MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "secureshield/window_flags")
//         .setMethodCallHandler { call, result ->
//             when (call.method) {
//                 "addFlags" -> { window.addFlags(call.argument<Int>("flags")!!); result.success(null) }
//                 "clearFlags" -> { window.clearFlags(call.argument<Int>("flags")!!); result.success(null) }
//                 else -> result.notImplemented()
//             }
//         }
// }

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controls Android's FLAG_SECURE window flag to prevent screenshots and
/// screen recording of sensitive UI.
///
/// Requires the corresponding MethodChannel handler to be registered in
/// MainActivity.kt (see the comment block at the top of this file).
///
/// Usage:
///   // Enable at sensitive screens
///   await ScreenshotPrevention.enable();
///
///   // Disable when leaving sensitive screens
///   await ScreenshotPrevention.disable();
///
///   // Or wrap a widget tree:
///   ScreenshotPrevention.protect(child: MySecretWidget())
class ScreenshotPrevention {
  ScreenshotPrevention._();

  static const _channel = MethodChannel('secureshield/window_flags');

  // Android FLAG_SECURE = 0x00002000 = 8192
  static const _flagSecure = 8192;

  // ---------------------------------------------------------------------------
  // Enable / disable
  // ---------------------------------------------------------------------------

  /// Apply FLAG_SECURE to the current Activity window on Android.
  ///
  /// Silently no-ops on non-Android platforms or if the channel is unavailable.
  static Future<void> enable() async {
    if (!defaultTargetPlatform.isAndroid) return;
    try {
      await _channel.invokeMethod('addFlags', {'flags': _flagSecure});
      debugPrint('[ScreenshotPrevention] FLAG_SECURE enabled.');
    } catch (e) {
      debugPrint('[ScreenshotPrevention] enable() failed (is MainActivity wired?): $e');
    }
  }

  /// Remove FLAG_SECURE from the current Activity window on Android.
  ///
  /// Silently no-ops on non-Android platforms or if the channel is unavailable.
  static Future<void> disable() async {
    if (!defaultTargetPlatform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearFlags', {'flags': _flagSecure});
      debugPrint('[ScreenshotPrevention] FLAG_SECURE disabled.');
    } catch (e) {
      debugPrint('[ScreenshotPrevention] disable() failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Widget wrapper
  // ---------------------------------------------------------------------------

  /// Wraps [child] in a widget that enables FLAG_SECURE when the widget is
  /// first built and disables it when the widget is disposed.
  ///
  /// Use this on screens that display OTP codes, evidence, AI conversations,
  /// or any other sensitive content.
  ///
  /// Example:
  ///   return ScreenshotPrevention.protect(child: OtpVaultScreen());
  static Widget protect({required Widget child}) {
    return _ScreenshotProtectedWrapper(child: child);
  }
}

// ---------------------------------------------------------------------------
// Internal StatefulWidget that manages FLAG_SECURE lifecycle
// ---------------------------------------------------------------------------
class _ScreenshotProtectedWrapper extends StatefulWidget {
  final Widget child;
  const _ScreenshotProtectedWrapper({required this.child});

  @override
  State<_ScreenshotProtectedWrapper> createState() =>
      _ScreenshotProtectedWrapperState();
}

class _ScreenshotProtectedWrapperState
    extends State<_ScreenshotProtectedWrapper> {
  @override
  void initState() {
    super.initState();
    ScreenshotPrevention.enable();
  }

  @override
  void dispose() {
    ScreenshotPrevention.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ---------------------------------------------------------------------------
// Extension helper
// ---------------------------------------------------------------------------
extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controls Android's FLAG_SECURE window flag, which blocks screenshots, the recents-screen thumbnail and
/// screen capture of the app's window (a protected window is blank in screen recordings).
///
/// The Kotlin side is `MainActivity.kt` (channel `secureshield/window_flags`, methods `enableSecure`,
/// `disableSecure`, `isSecure`). `test/core/screenshot_prevention_test.dart` fails if the method names used
/// here stop matching the Kotlin source.
///
/// Several protected screens can be on the navigation stack at once, so the flag is reference counted: it is
/// set when the first holder appears and cleared only when the last holder is gone. It is re-applied when
/// the app returns to the foreground in case the activity was recreated.
///
/// Limits (Android): it does not stop a photo of the screen, accessibility services or a rooted/instrumented
/// device from reading the window, and it protects only this app's window.
///
/// Usage: `ScreenshotPrevention.protect(child: SomeSensitiveScreen())`.
class ScreenshotPrevention {
  ScreenshotPrevention._();

  static MethodChannel _channel = const MethodChannel('secureshield/window_flags');

  static int _holders = 0;
  // Platform calls are applied strictly in order so a fast navigate-away cannot leave the flag set.
  static Future<void>? _chain;

  /// Number of widgets currently asking for protection.
  @visibleForTesting
  static int get holders => _holders;

  @visibleForTesting
  static void resetForTesting({MethodChannel? channel}) {
    _holders = 0;
    _chain = null;
    _channel = channel ?? const MethodChannel('secureshield/window_flags');
  }

  static bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _apply(String method) {
    _chain = (_chain ?? Future<void>.value()).then((_) async {
      if (!_supported) return;
      try {
        await _channel.invokeMethod<void>(method);
      } catch (e) {
        debugPrint('[ScreenshotPrevention] $method failed: ${e.runtimeType}');
      }
    });
    return _chain!;
  }

  static Future<void> get _queue => _chain ?? Future<void>.value();

  /// Registers one holder; the first holder turns FLAG_SECURE on.
  static Future<void> enable() {
    _holders++;
    return _holders == 1 ? _apply('enableSecure') : _queue;
  }

  /// Releases one holder; FLAG_SECURE is cleared only when none remain.
  static Future<void> disable() {
    if (_holders == 0) return _queue;
    _holders--;
    return _holders == 0 ? _apply('disableSecure') : _queue;
  }

  /// Re-asserts the flag if any holder exists (called when the app resumes).
  static Future<void> reapply() => _holders > 0 ? _apply('enableSecure') : _queue;

  /// Whether the window currently carries FLAG_SECURE (null when the platform cannot say).
  static Future<bool?> isSecure() async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<bool>('isSecure');
    } catch (_) {
      return null;
    }
  }

  /// Wraps [child] so FLAG_SECURE is held while the widget is in the tree.
  static Widget protect({required Widget child}) => _ScreenshotProtected(child: child);
}

class _ScreenshotProtected extends StatefulWidget {
  final Widget child;
  const _ScreenshotProtected({required this.child});

  @override
  State<_ScreenshotProtected> createState() => _ScreenshotProtectedState();
}

class _ScreenshotProtectedState extends State<_ScreenshotProtected> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ScreenshotPrevention.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ScreenshotPrevention.reapply();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ScreenshotPrevention.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../../../core/security/device_scanner_service.dart';
import '../../../core/security/app_risk_engine.dart';
import '../scan_provider.dart';

// ────────────────────────────────────────────────────────────────────────────
// Scan phase definitions
// ────────────────────────────────────────────────────────────────────────────
class _Phase {
  final IconData icon;
  final String label;
  const _Phase(this.icon, this.label);
}

const _phases = [
  _Phase(Icons.apps_rounded,      'Scanning installed apps'),
  _Phase(Icons.security_rounded,  'Checking permissions'),
  _Phase(Icons.accessibility_new, 'Auditing accessibility services'),
  _Phase(Icons.network_check,     'Analyzing network usage'),
  _Phase(Icons.shield_rounded,    'Compiling risk report'),
];

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────
class DeviceScanScreen extends ConsumerStatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  ConsumerState<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends ConsumerState<DeviceScanScreen>
    with TickerProviderStateMixin {
  // Radar sweep animation
  late final AnimationController _radarCtrl;
  // Pulse animation on shield icon
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  int    _phaseIndex = 0;
  int    _appsFound  = 0;
  bool   _done       = false;
  String _error      = '';

  @override
  void initState() {
    super.initState();

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start the actual scan after one frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _runScan());
  }

  @override
  void dispose() {
    _radarCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Real scan logic ───────────────────────────────────────────────────────
  Future<void> _runScan() async {
    try {
      // Phase 0 — fetch installed apps
      await _setPhase(0);
      final apps = await DeviceScannerService.getInstalledApps();
      if (mounted) setState(() => _appsFound = apps.length);

      // Phase 1 — permissions (UI delay)
      await _setPhase(1, delay: 600);

      // Phase 2 — accessibility services
      await _setPhase(2, delay: 500);
      final accessibility = await DeviceScannerService.getAccessibilityServices();

      // Phase 3 — network (UI delay)
      await _setPhase(3, delay: 600);

      // Phase 4 — risk engine
      await _setPhase(4, delay: 400);
      final summary = AppRiskEngine.analyze(apps, accessibility);

      if (!mounted) return;

      // Stop animations and navigate to results
      setState(() => _done = true);
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        context.pushReplacement('/scan-result', extra: summary);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _setPhase(int index, {int delay = 0}) async {
    if (delay > 0) await Future.delayed(Duration(milliseconds: delay));
    if (mounted) setState(() => _phaseIndex = index);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // ── Header ──────────────────────────────────────────────────
              Text(
                'Device Security Scan',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Checking your device for security threats\nbefore you continue',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // ── Radar / Shield animation ────────────────────────────────
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric rings
                    _Ring(radius: 95, opacity: 0.08),
                    _Ring(radius: 75, opacity: 0.12),
                    _Ring(radius: 55, opacity: 0.18),

                    // Rotating sweep
                    if (!_done)
                      AnimatedBuilder(
                        animation: _radarCtrl,
                        builder: (_, __) => Transform.rotate(
                          angle: _radarCtrl.value * 2 * pi,
                          child: CustomPaint(
                            size: const Size(190, 190),
                            painter: _RadarSweepPainter(),
                          ),
                        ),
                      ),

                    // Pulsing shield icon
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: _done ? 1.0 : _pulseAnim.value,
                        child: child,
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.4),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _done
                              ? Icons.verified_rounded
                              : Icons.shield_rounded,
                          size: 44,
                          color: _done ? AppTheme.success : AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Apps found counter ──────────────────────────────────────
              if (_appsFound > 0)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '$_appsFound apps found',
                    key: ValueKey(_appsFound),
                    style: TextStyle(
                      color: AppTheme.accent.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Phase list ─────────────────────────────────────────────
              ...List.generate(_phases.length, (i) {
                final phase    = _phases[i];
                final isDone   = i < _phaseIndex || _done;
                final isActive = i == _phaseIndex && !_done;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.accent.withOpacity(0.08)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? AppTheme.accent.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle_rounded : phase.icon,
                        size: 20,
                        color: isDone
                            ? AppTheme.success
                            : isActive
                                ? AppTheme.accent
                                : AppTheme.textSecondary.withOpacity(0.4),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          phase.label,
                          style: TextStyle(
                            color: isDone
                                ? AppTheme.textSecondary
                                : isActive
                                    ? AppTheme.textPrimary
                                    : AppTheme.textSecondary.withOpacity(0.4),
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isActive)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.accent,
                          ),
                        ),
                    ],
                  ),
                );
              }),

              // ── Error state ────────────────────────────────────────────
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Text('Scan failed', style: TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() { _error = ''; _phaseIndex = 0; });
                          _runScan();
                        },
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: _skip,
                        child: const Text('Skip Scan'),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // ── Skip option ────────────────────────────────────────────
              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip scan (not recommended)',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _skip() {
    ref.read(deviceScanDoneProvider.notifier).state = true;
    context.go('/welcome');
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: simple ring widget
// ────────────────────────────────────────────────────────────────────────────
class _Ring extends StatelessWidget {
  final double radius;
  final double opacity;
  const _Ring({required this.radius, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.accent.withOpacity(opacity),
            width: 1.5,
          ),
        ),
      );
}

// ────────────────────────────────────────────────────────────────────────────
// Helper: radar sweep gradient arc painter
// ────────────────────────────────────────────────────────────────────────────
class _RadarSweepPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradient = SweepGradient(
      colors: [
        const Color(0xFF00E5FF).withOpacity(0),
        const Color(0xFF00E5FF).withOpacity(0.35),
        const Color(0xFF00E5FF).withOpacity(0),
      ],
      stops: const [0.0, 0.25, 0.30],
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
    );

    final paint = Paint()
      ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../qr_safety_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  QrSafetyReport? _report;
  String? _scannedPayload;
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_processing) return;
    final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    if (raw == _scannedPayload) return;

    setState(() {
      _processing = true;
      _scannedPayload = raw;
      _report = QrSafetyService.analyze(raw);
    });
    _controller.stop();
  }

  void _rescan() {
    setState(() {
      _report = null;
      _scannedPayload = null;
      _processing = false;
    });
    _controller.start();
  }

  void _openLinkScanner() {
    if (_report?.extracted['url'] != null) {
      context.push('/link-scanner', extra: _report!.extracted['url']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'QR Safety Scanner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (context, state, _) {
                switch (state.torchState) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.white);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Color(0xFFFFEB3B));
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.white);
                  case TorchState.unavailable:
                    return const Icon(Icons.flash_off, color: Colors.white38);
                }
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                  ),
                  // Viewfinder overlay
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF00E5FF),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.qr_code_scanner, color: Color(0xFF00E5FF), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Position the QR code inside the box',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0A0E27),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: _report == null ? _waitingState() : _resultState(_report!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _waitingState() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.security, size: 40, color: Color(0xFF00E5FF)),
        SizedBox(height: 12),
        Text(
          'Ready to scan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'SecureShield will verify UPI VPAs and run URLs through Google Safe Browsing + URLhaus.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF90A4AE), fontSize: 12.5, height: 1.4),
        ),
      ],
    );
  }

  Widget _resultState(QrSafetyReport report) {
    final (color, icon) = _verdictStyle(report.verdict);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.headline,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (report.extracted.isNotEmpty) ...[
            ...report.extracted.entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      e.key.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF90A4AE),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      e.value,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 10),
          ],
          ...report.reasons.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.chevron_right, color: color, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    r,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rescan,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (report.routeForFurtherCheck == '/link-scanner') ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openLinkScanner,
                    icon: const Icon(Icons.travel_explore, size: 18),
                    label: const Text('Run full URL scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: const Color(0xFF0A0E27),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (Color, IconData) _verdictStyle(QrSafetyVerdict v) {
    switch (v) {
      case QrSafetyVerdict.safe:
        return (const Color(0xFF4CAF50), Icons.verified);
      case QrSafetyVerdict.caution:
        return (const Color(0xFFFF9800), Icons.warning_amber);
      case QrSafetyVerdict.danger:
        return (const Color(0xFFFF1744), Icons.gpp_bad);
      case QrSafetyVerdict.unknown:
        return (const Color(0xFF90A4AE), Icons.help_outline);
    }
  }
}

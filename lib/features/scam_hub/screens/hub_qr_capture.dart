import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Minimal camera page: returns the first QR payload it reads and does nothing else (no analysis, no network, no launch).
class HubQrCapturePage extends StatefulWidget {
  const HubQrCapturePage({super.key});

  @override
  State<HubQrCapturePage> createState() => _HubQrCapturePageState();
}

class _HubQrCapturePageState extends State<HubQrCapturePage> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal, facing: CameraFacing.back);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue : null;
    if (raw == null || raw.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(raw);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan a QR code')),
        body: MobileScanner(controller: _controller, onDetect: _onDetect),
      );
}

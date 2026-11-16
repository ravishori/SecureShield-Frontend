import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../payment_screenshot_verifier.dart';
import 'package:secureshield_app/core/utils/safe_error.dart';

class PaymentVerifierScreen extends StatefulWidget {
  const PaymentVerifierScreen({super.key});

  @override
  State<PaymentVerifierScreen> createState() => _PaymentVerifierScreenState();
}

class _PaymentVerifierScreenState extends State<PaymentVerifierScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _ocr = TextRecognizer(script: TextRecognitionScript.latin);

  File? _imageFile;
  PaymentScreenshotReport? _report;
  bool _processing = false;
  String? _error;

  @override
  void dispose() {
    _ocr.close();
    super.dispose();
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    setState(() {
      _error = null;
      _report = null;
      _processing = true;
    });
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) {
        setState(() => _processing = false);
        return;
      }
      final file = File(picked.path);
      final inputImage = InputImage.fromFile(file);
      final result = await _ocr.processImage(inputImage);

      final report = PaymentScreenshotVerifier.analyze(result.text);
      setState(() {
        _imageFile = file;
        _report = report;
        _processing = false;
      });
    } catch (e) {
      setState(() {
        _error = safeErrorMessage(e, prefix: 'Could not analyze image');
        _processing = false;
      });
    }
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _report = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E27),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Payment Screenshot Verifier',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_report != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_report == null) _intro(),
              if (_imageFile != null) ...[
                const SizedBox(height: 16),
                _imagePreview(),
              ],
              if (_processing) ...[
                const SizedBox(height: 24),
                _processingState(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _errorCard(_error!),
              ],
              if (_report != null) ...[
                const SizedBox(height: 16),
                _verdictCard(_report!),
                const SizedBox(height: 12),
                _checksCard(_report!),
                if (_report!.extractedTxnId != null ||
                    _report!.extractedAmount != null) ...[
                  const SizedBox(height: 12),
                  _extractedCard(_report!),
                ],
              ],
              const SizedBox(height: 24),
              _actionButtons(),
              const SizedBox(height: 16),
              _disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF0277BD)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.receipt_long, color: Colors.white, size: 36),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Before you ship the goods',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fake UPI/PhonePe/GPay screenshots cost SMBs in India ₹400+ cr a year. Run any payment proof through this verifier in under 5 seconds.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        _imageFile!,
        height: 280,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _processingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: Color(0xFF00E5FF)),
          SizedBox(height: 12),
          Text(
            'Running on-device OCR and forensic checks…',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5252).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFFF5252)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5252)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verdictCard(PaymentScreenshotReport report) {
    final (color, icon, label) = _verdictStyle(report.verdict);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: report.confidence / 100,
            backgroundColor: Colors.white12,
            color: color,
            minHeight: 6,
          ),
          const SizedBox(height: 6),
          Text(
            'Confidence: ${report.confidence}%',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _checksCard(PaymentScreenshotReport report) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forensic checks',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...report.checks.map((c) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_checkIcon(c.outcome), color: _checkColor(c.outcome), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.detail,
                        style: const TextStyle(
                          color: Color(0xFF90A4AE),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _extractedCard(PaymentScreenshotReport r) {
    final rows = <(String, String?)>[
      ('App',          r.detectedApp),
      ('Amount',       r.extractedAmount),
      ('Transaction ID', r.extractedTxnId),
      ('UPI Ref No',   r.extractedUpiRefNo),
      ('Date',         r.extractedDate),
      ('Receiver VPA', r.extractedReceiverVpa),
    ].where((e) => e.$2 != null).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2233),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Extracted information',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    r.$1,
                    style: const TextStyle(
                      color: Color(0xFF90A4AE),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    r.$2 ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _processing
                ? null
                : () => _pickAndAnalyze(ImageSource.camera),
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Take photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00E5FF),
              side: const BorderSide(color: Color(0xFF00E5FF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _processing
                ? null
                : () => _pickAndAnalyze(ImageSource.gallery),
            icon: const Icon(Icons.photo_library, size: 20),
            label: const Text('Pick screenshot'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF0A0E27),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withValues(alpha: 0.08),
        border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'This is a forensic preview. For high-value transactions always verify the inflow in your bank statement / UPI app before delivering goods.',
              style: TextStyle(color: Color(0xFFFF9800), fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _verdictStyle(PaymentVerdict v) {
    switch (v) {
      case PaymentVerdict.authentic:
        return (const Color(0xFF4CAF50), Icons.verified, 'Likely authentic');
      case PaymentVerdict.inconclusive:
        return (const Color(0xFFFF9800), Icons.help_outline, 'Inconclusive');
      case PaymentVerdict.suspicious:
        return (const Color(0xFFFF9800), Icons.warning_amber, 'Suspicious');
      case PaymentVerdict.fake:
        return (const Color(0xFFFF1744), Icons.gpp_bad, 'Likely fake');
    }
  }

  IconData _checkIcon(CheckOutcome o) {
    switch (o) {
      case CheckOutcome.pass:
        return Icons.check_circle;
      case CheckOutcome.fail:
        return Icons.cancel;
      case CheckOutcome.warn:
        return Icons.warning;
      case CheckOutcome.info:
        return Icons.info;
    }
  }

  Color _checkColor(CheckOutcome o) {
    switch (o) {
      case CheckOutcome.pass:
        return const Color(0xFF4CAF50);
      case CheckOutcome.fail:
        return const Color(0xFFFF1744);
      case CheckOutcome.warn:
        return const Color(0xFFFF9800);
      case CheckOutcome.info:
        return const Color(0xFF00E5FF);
    }
  }
}

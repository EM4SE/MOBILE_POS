import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/feedback_helper.dart';

/// Full-Width Seamless Bottom Sheet for Live Camera Barcode Scanning
/// Continuous multi-item scanning with native tone generator beep and hardware vibration
class CameraBarcodeScannerSheet extends StatefulWidget {
  final void Function(String barcode) onBarcodeScanned;

  const CameraBarcodeScannerSheet({
    super.key,
    required this.onBarcodeScanned,
  });

  static Future<void> show(BuildContext context, {required void Function(String barcode) onBarcodeScanned}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CameraBarcodeScannerSheet(onBarcodeScanned: onBarcodeScanned),
    );
  }

  @override
  State<CameraBarcodeScannerSheet> createState() => _CameraBarcodeScannerSheetState();
}

class _CameraBarcodeScannerSheetState extends State<CameraBarcodeScannerSheet> {
  late final MobileScannerController _scannerController;
  bool _isTorchOn = false;
  CameraFacing _facing = CameraFacing.back;
  DateTime _lastScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastScannedCode;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    final now = DateTime.now();
    // 1.5 second throttle to avoid duplicate rapid captures of the same item
    if (now.difference(_lastScanTime).inMilliseconds < 1500) {
      return;
    }

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _lastScanTime = now;
        final cleanCode = code.trim();

        // 1. Play native POS scanner beep and hardware vibration
        FeedbackHelper.playScanFeedback();

        setState(() {
          _lastScannedCode = cleanCode;
        });

        // 2. Trigger cart add callback (continuous multi-item scanning)
        widget.onBarcodeScanned(cleanCode);

        _feedbackTimer?.cancel();
        _feedbackTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _lastScannedCode = null;
            });
          }
        });
        break;
      }
    }
  }

  void _toggleCameraFacing() {
    _scannerController.switchCamera();
    setState(() {
      _facing = _facing == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
    });
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() {
      _isTorchOn = !_isTorchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.headerBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---------------------------------------------------------------
            // Top Bar: Clean Header with only BARCODE SCANNER, Flip, Torch & Close
            // (No count in header as requested)
            // ---------------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2631),
                border: Border(
                  bottom: BorderSide(color: Colors.white24, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'BARCODE SCANNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Front / Back Camera Switch Button
                  IconButton(
                    icon: Icon(
                      _facing == CameraFacing.back ? Icons.camera_rear : Icons.camera_front,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Switch Camera',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _toggleCameraFacing,
                  ),

                  const SizedBox(width: 6),

                  // Torch / Flash Toggle
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.amber : Colors.white70,
                      size: 20,
                    ),
                    tooltip: 'Flash',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: _toggleTorch,
                  ),

                  const SizedBox(width: 6),

                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------------------
            // Camera Live Viewfinder Area (Continuous scanning without keyboard popup)
            // ---------------------------------------------------------------
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Real-time Camera Preview
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _handleBarcode,
                    errorBuilder: (context, error, child) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off, color: Colors.white54, size: 36),
                              const SizedBox(height: 6),
                              Text(
                                'Camera active or device busy: ${error.errorCode.name}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Targeting Frame Guides
                  Container(
                    width: 200,
                    height: 130,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _lastScannedCode != null ? AppColors.success : AppColors.accent,
                        width: _lastScannedCode != null ? 3 : 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),

                  // Red/Green Laser Scan Line
                  Container(
                    width: 210,
                    height: 2,
                    color: (_lastScannedCode != null ? AppColors.success : AppColors.error).withOpacity(0.9),
                  ),

                  // Scanned Success Notification Overlay
                  if (_lastScannedCode != null) ...[
                    Positioned(
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Added: $_lastScannedCode',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Instruction Tag
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Align barcode inside frame • Continuous scanning',
                        style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------------------
            // Bottom Done Action Button
            // ---------------------------------------------------------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              color: const Color(0xFF151B22),
              child: SizedBox(
                height: 42,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text(
                    'DONE SCANNING',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

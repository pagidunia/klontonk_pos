import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/app_deps.dart';

/// Buka kamera untuk memindai barcode. Mengembalikan teks barcode, atau null bila dibatalkan.
/// Kamera awal (belakang/depan) mengikuti pilihan di Pengaturan; mengganti kamera di layar ini ikut menyimpan pilihan.
/// Izin kamera ditolak / tidak ada kamera ditampilkan sebagai pesan di layar pemindai.
Future<String?> scanBarcode(BuildContext context) {
  final prefs = context.read<AppDeps>().prefs;
  return Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => _ScannerPage(startFront: prefs.scanFront, onFacingChanged: (front) => prefs.setScanFront(front)),
    fullscreenDialog: true,
  ));
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.startFront, required this.onFacingChanged});
  final bool startFront;
  final ValueChanged<bool> onFacingChanged;

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  late final _controller = MobileScannerController(facing: widget.startFront ? CameraFacing.front : CameraFacing.back, detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.qrCode]);
  bool _done = false;
  CameraFacing? _lastFacing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onState);
  }

  /// Simpan pilihan kamera setiap kali berganti arah (depan/belakang).
  void _onState() {
    final facing = _controller.value.cameraDirection;
    if (facing == CameraFacing.unknown || facing == CameraFacing.external || facing == _lastFacing) return;
    final first = _lastFacing == null;
    _lastFacing = facing;
    if (!first) widget.onFacingChanged(facing == CameraFacing.front);
  }

  @override
  void dispose() {
    _controller.removeListener(_onState);
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan Barcode'),
          actions: [
            IconButton(icon: const Icon(Icons.flash_on), tooltip: 'Senter', onPressed: _controller.toggleTorch),
            IconButton(icon: const Icon(Icons.cameraswitch_outlined), tooltip: 'Ganti kamera', onPressed: _controller.switchCamera),
          ],
        ),
        body: Stack(children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _pesanKamera(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
          Center(child: Container(width: 260, height: 160, decoration: BoxDecoration(border: Border.all(color: Colors.white70, width: 2), borderRadius: BorderRadius.circular(16)))),
          const Positioned(left: 0, right: 0, bottom: 40, child: Text('Arahkan kamera ke barcode barang', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14))),
        ]),
      );
}

/// Pesan ramah untuk galat kamera. `unsupported` = perangkat tidak punya kamera yang bisa dipakai
/// (mis. iOS Simulator tidak punya kamera sama sekali).
String _pesanKamera(MobileScannerException error) => switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => 'Izin kamera ditolak. Aktifkan izin kamera untuk aplikasi ini di pengaturan perangkat.',
      MobileScannerErrorCode.unsupported => 'Perangkat ini tidak punya kamera yang bisa dipakai (iOS Simulator tidak memiliki kamera).\n\nCoba di HP sungguhan, atau ketik barcode secara manual.',
      _ => 'Kamera tidak bisa dibuka (${error.errorCode.name}).',
    };

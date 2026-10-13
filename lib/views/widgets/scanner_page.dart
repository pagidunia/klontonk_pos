import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Buka kamera untuk memindai barcode. Mengembalikan teks barcode, atau null bila dibatalkan.
/// Izin kamera ditolak / tidak ada kamera ditampilkan sebagai pesan di layar pemindai.
Future<String?> scanBarcode(BuildContext context) => Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage(), fullscreenDialog: true));

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates, formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39, BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
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
            errorBuilder: (context, error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied ? 'Izin kamera ditolak. Aktifkan izin kamera di pengaturan perangkat.' : 'Kamera tidak bisa dibuka (${error.errorCode.name}).',
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

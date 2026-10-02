import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerQrScreen extends StatefulWidget {
  const ScannerQrScreen({super.key});

  @override
  State<ScannerQrScreen> createState() => _ScannerQrScreenState();
}

class _ScannerQrScreenState extends State<ScannerQrScreen> {
  bool _gestito = false;

  void _onDetect(BarcodeCapture capture) {
    if (_gestito) return;
    if (capture.barcodes.isEmpty) return;
    final valore = capture.barcodes.first.rawValue;
    if (valore != null) {
      _gestito = true;
      Navigator.pop(context, valore);
    }
  }

  String _messaggioErrore(MobileScannerException errore) {
    switch (errore.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Permesso fotocamera negato.\nAbilitalo nelle impostazioni del telefono per Gymapp.';
      case MobileScannerErrorCode.unsupported:
        return 'Questo dispositivo non supporta la scansione.';
      default:
        return 'Non riesco ad aprire la fotocamera.\nRiprova più tardi.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inquadra il QR della scheda')),
      body: MobileScanner(
        onDetect: _onDetect,
        errorBuilder: (context, errore, child) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _messaggioErrore(errore),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Scanner del QR di una scheda. Avvia la fotocamera in modo esplicito e
/// mostra sullo schermo cosa sta succedendo (utile per capire eventuali errori).
class ScannerQrScreen extends StatefulWidget {
  const ScannerQrScreen({super.key});

  @override
  State<ScannerQrScreen> createState() => _ScannerQrScreenState();
}

class _ScannerQrScreenState extends State<ScannerQrScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  StreamSubscription<BarcodeCapture>? _sub;
  bool _gestito = false;
  bool _torcia = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _controller.barcodes.listen(_onCattura);
    _avvia();
  }

  void _avvia() {
    _controller.start().catchError((Object _) {});
  }

  void _onCattura(BarcodeCapture capture) {
    if (_gestito || capture.barcodes.isEmpty) return;
    final valore = capture.barcodes.first.rawValue;
    if (valore != null && mounted) {
      _gestito = true;
      Navigator.pop(context, valore);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _sub ??= _controller.barcodes.listen(_onCattura);
      _avvia();
    } else if (state == AppLifecycleState.inactive) {
      _sub?.cancel();
      _sub = null;
      _controller.stop().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _messaggioErrore(MobileScannerException errore) {
    switch (errore.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Permesso fotocamera negato.\nAbilitalo da Impostazioni > App > Gymapp > Autorizzazioni.';
      case MobileScannerErrorCode.unsupported:
        return 'Questo dispositivo non supporta la scansione.';
      default:
        return 'Non riesco ad aprire la fotocamera.\nCodice: ${errore.errorCode.name}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Inquadra il QR della scheda'),
        actions: [
          IconButton(
            tooltip: 'Torcia',
            icon: Icon(_torcia ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              try {
                await _controller.toggleTorch();
                if (mounted) setState(() => _torcia = !_torcia);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF39FF14), width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, stato, _) {
              final errore = stato.error;
              String? messaggio;
              if (errore != null) {
                messaggio = _messaggioErrore(errore);
              } else if (!stato.isInitialized) {
                messaggio = 'Avvio della fotocamera...';
              }
              if (messaggio == null) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.78),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        messaggio,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (errore != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _avvia,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

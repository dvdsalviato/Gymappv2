import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data/immagini_esercizi.dart';
import 'db/database_helper.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/sfondo_texturizzato.dart';

/// Errori arrivati durante l'avvio: si mostrano a schermo invece di lasciare l'app bloccata.
final List<String> _erroriAvvio = [];

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // Licenze dei font inclusi (SIL Open Font License), visibili tra le licenze dell'app.
    LicenseRegistry.addLicense(() async* {
      for (final font in const ['Oswald', 'Barlow']) {
        final testo = await rootBundle.loadString('assets/google_fonts/OFL-$font.txt');
        yield LicenseEntryWithLineBreaks([font], testo);
      }
    });
    FlutterError.onError = (dettagli) {
      FlutterError.presentError(dettagli);
      _erroriAvvio.add('${dettagli.exceptionAsString()}\n${dettagli.stack ?? ''}');
    };
    runApp(const _Avvio());
  }, (errore, stack) {
    _erroriAvvio.add('$errore\n$stack');
  });
}

/// Prepara tema e database passo per passo. Se tutto va bene parte l'app,
/// altrimenti mostra a che punto si è fermato e il messaggio d'errore.
class _Avvio extends StatefulWidget {
  const _Avvio();

  @override
  State<_Avvio> createState() => _AvvioState();
}

class _AvvioState extends State<_Avvio> {
  final List<String> _passi = [];
  String? _errore;
  bool _pronto = false;

  @override
  void initState() {
    super.initState();
    _avvia();
  }

  Future<void> _passo(String nome, Future<void> Function() azione) async {
    final cronometro = Stopwatch()..start();
    setState(() => _passi.add('$nome…'));
    final indice = _passi.length - 1;
    await azione().timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException('$nome non risponde da 15 secondi'),
    );
    if (mounted) setState(() => _passi[indice] = '$nome: ok (${cronometro.elapsedMilliseconds} ms)');
  }

  Future<void> _avvia() async {
    try {
      await _passo('Preferenze e tema', () => ThemeController.carica());
      await _passo('Database', () async {
        await DatabaseHelper.instance.database;
      });
      await _passo('Immagini scelte', caricaImmaginiScelte);
      if (mounted) setState(() => _pronto = true);
    } catch (e, s) {
      if (mounted) setState(() => _errore = '$e\n\n$s');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pronto) return const GymappApp();
    final righe = <String>[
      ..._passi,
      if (_errore != null) '\nERRORE:\n$_errore',
      if (_erroriAvvio.isNotEmpty) '\nErrori durante l\'avvio:\n${_erroriAvvio.join('\n---\n')}',
    ];
    final testo = righe.join('\n');
    final conProblemi = _errore != null || _erroriAvvio.isNotEmpty;
    // Avvio normale: solo una rotellina discreta, senza testo tecnico.
    // L'elenco dei passi compare solo se qualcosa va storto.
    if (!conProblemi) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF15141A),
          body: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54),
            ),
          ),
        ),
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gymapp · avvio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(testo, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                ),
                if (conProblemi)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Clipboard.setData(ClipboardData(text: testo)),
                          child: const Text('Copia'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => setState(() => _pronto = true),
                          child: const Text('Apri comunque'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Su schermi larghi (webapp sul computer, tablet) l'app resta centrata con
/// una larghezza da telefono, invece di allargarsi su tutto lo schermo.
class _LarghezzaTelefono extends StatelessWidget {
  final Widget child;
  const _LarghezzaTelefono({required this.child});

  static const _larghezza = 560.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, vincoli) {
      if (vincoli.maxWidth <= 720) return child;
      final media = MediaQuery.of(context);
      return Center(
        child: Container(
          width: _larghezza,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
            ),
          ),
          child: ClipRect(
            child: MediaQuery(
              data: media.copyWith(size: Size(_larghezza, vincoli.maxHeight)),
              child: child,
            ),
          ),
        ),
      );
    });
  }
}

class GymappApp extends StatelessWidget {
  const GymappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeController.modalita,
        ThemeController.colore,
        ThemeController.personalizzato,
      ]),
      builder: (context, _) {
        final modalita = ThemeController.modalita.value;
        return MaterialApp(
          title: 'Gymapp',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: modalita,
          builder: (context, child) => SfondoTexturizzato(
            scuro: modalita == ThemeMode.dark,
            accento: coloreAppAttuale.scuro,
            child: _LarghezzaTelefono(child: child ?? const SizedBox.shrink()),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

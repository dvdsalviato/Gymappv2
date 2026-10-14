import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../state/sessione_allenamento.dart';
import '../widgets/dialogo_azioni.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'amici_screen.dart';
import 'home_screen.dart';
import 'profilo_screen.dart';
import 'schede_screen.dart';
import 'storico_screen.dart';
import 'workout_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _indice = 0;
  String? _nome;

  @override
  void initState() {
    super.initState();
    _caricaNome();
    _ripristinaAllenamento();
    _riclassificaEsercizi();
  }

  /// Dà una categoria agli esercizi rimasti "Altro" quando il nome è
  /// riconoscibile (una volta sola per avvio, in silenzio).
  Future<void> _riclassificaEsercizi() async {
    try {
      await DatabaseHelper.instance.riclassificaAltro();
    } catch (_) {}
  }

  /// Se l'app era stata chiusa durante un allenamento, propone di riprenderlo.
  Future<void> _ripristinaAllenamento() async {
    final trovato = await GestoreSessione.caricaDaDisco();
    if (!trovato || !mounted) return;
    setState(() {});
    final sessione = GestoreSessione.inPausa;
    if (sessione == null) return;
    final scelta = await mostraDialogoAzioni<String>(
      context,
      titolo: 'Allenamento interrotto',
      messaggio: '"${sessione.nomeScheda}" era rimasto a metà. Vuoi riprenderlo da dove eri?',
      azioni: const [
        AzioneDialogo('Riprendi', Icons.play_arrow, 'riprendi', stile: StileAzione.primaria),
        AzioneDialogo('Decido dopo', Icons.schedule, 'dopo'),
        AzioneDialogo('Scarta', Icons.delete_outline, 'scarta', stile: StileAzione.pericolo),
      ],
    );
    if (!mounted) return;
    if (scelta == 'riprendi') {
      GestoreSessione.inPausa = null;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutScreen(
            esercizi: sessione.coda.map((v) => v.esercizio).toList(),
            nomeScheda: sessione.nomeScheda,
            ripresaDa: sessione,
          ),
        ),
      );
      if (mounted) setState(() {});
    } else if (scelta == 'scarta') {
      GestoreSessione.inPausa = null;
      GestoreSessione.inizioAllenamento = null;
      await GestoreSessione.cancellaSalvata();
      setState(() {});
    }
  }

  Future<void> _caricaNome() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    final nome = (profilo?['nome'] as String?)?.trim();
    if (mounted) {
      setState(() => _nome = (nome != null && nome.isNotEmpty) ? nome : null);
    }
    if (nome == null || nome.isEmpty) {
      // Aspettiamo un frame per essere sicuri di avere un context valido
      // per mostrare il dialogo.
      WidgetsBinding.instance.addPostFrameCallback((_) => _chiediNome());
    }
  }

  Future<void> _chiediNome() async {
    if (!mounted) return;
    final ctrl = TextEditingController();
    final inserito = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Come ti chiami?'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Il tuo nome'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Salta'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    if (inserito != null && inserito.isNotEmpty) {
      // Uniamo al profilo esistente, per non cancellare altezza/peso/ecc.
      // se erano già stati salvati.
      final profiloAttuale = await DatabaseHelper.instance.getProfilo() ?? {};
      await DatabaseHelper.instance.salvaProfilo({...profiloAttuale, 'nome': inserito});
      if (mounted) setState(() => _nome = inserito);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GYMAPP'),
        actions: [
          // Cambio tema: prima stava nel menu laterale, ora è sempre a portata di mano.
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.modalita,
            builder: (context, modalita, _) => IconButton(
              tooltip: modalita == ThemeMode.dark ? 'Tema chiaro' : 'Tema scuro',
              icon: Icon(modalita == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
              onPressed: () => ThemeController.cambia(modalita != ThemeMode.dark),
            ),
          ),
        ],
      ),
      // Niente IndexedStack: ricreiamo la schermata a ogni cambio tab così i
      // dati (es. lo storico appena salvato) vengono ricaricati sempre.
      body: _corpo(),
      bottomNavigationBar: _barraNavigazione(context),
    );
  }

  Widget _corpo() {
    switch (_indice) {
      case 0:
        return HomeScreen(nome: _nome, onVaiAlleSchede: () => setState(() => _indice = 1));
      case 1:
        return const SchedeScreen();
      case 2:
        return const StoricoScreen();
      case 3:
        return const AmiciScreen();
      default:
        return ProfiloScreen(incorporata: true, onSalvato: _aggiornaNome);
    }
  }

  Future<void> _aggiornaNome() async {
    final profilo = await DatabaseHelper.instance.getProfilo();
    final nome = (profilo?['nome'] as String?)?.trim();
    if (mounted) setState(() => _nome = (nome != null && nome.isNotEmpty) ? nome : null);
  }

  /// Barra in basso a pillola, con icone tonde: quella attiva diventa verde fluo.
  Widget _barraNavigazione(BuildContext context) {
    final voci = [
      (Icons.home_outlined, Icons.home, 'Home'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Schede'),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'Storico'),
      (Icons.group_outlined, Icons.group, 'Amici'),
      (Icons.person_outline, Icons.person, 'Profilo'),
    ];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: coloreCard(context),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < voci.length; i++)
              Semantics(
                label: voci[i].$3,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _indice = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _indice == i ? AppColors.accento : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _indice == i ? voci[i].$2 : voci[i].$1,
                      color: _indice == i ? Colors.black : Colors.grey.shade500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

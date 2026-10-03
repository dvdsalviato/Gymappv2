import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'assistente_screen.dart';
import 'calendario_screen.dart';
import 'mappa_muscolare_screen.dart';
import 'home_screen.dart';
import 'peso_screen.dart';
import 'profilo_screen.dart';
import 'schede_screen.dart';
import 'storico_screen.dart';

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
      appBar: AppBar(title: const Text('GYMAPP')),
      drawer: _buildDrawer(context),
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
        return const PesoScreen();
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
      (Icons.monitor_weight_outlined, Icons.monitor_weight, 'Peso'),
      (Icons.person_outline, Icons.person, 'Profilo'),
    ];
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 6, 20, 14),
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
                    width: 50,
                    height: 50,
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.modalita,
          builder: (context, modalita, _) {
            return ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      'Gymapp',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Tema scuro'),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: modalita == ThemeMode.dark,
                  onChanged: (v) => ThemeController.cambia(v),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Il mio profilo'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _indice = 4);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: const Text('Calendario presenze'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CalendarioScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility_new),
                  title: const Text('Mappa muscolare'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MappaMuscolareScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('Assistente AI'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AssistenteScreen()),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

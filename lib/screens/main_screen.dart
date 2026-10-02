import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/theme_controller.dart';
import 'assistente_screen.dart';
import 'calendario_screen.dart';
import 'mappa_muscolare_screen.dart';
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
      appBar: AppBar(title: Text(_nome != null ? 'Gymapp V2, $_nome' : 'Gymapp V2')),
      drawer: _buildDrawer(context),
      // Niente IndexedStack: ricreiamo la schermata a ogni cambio tab così i
      // dati (es. lo storico appena salvato) vengono ricaricati sempre.
      body: _indice == 0 ? const SchedeScreen() : const StoricoScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Schede'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Storico'),
        ],
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
                      'Gymapp V2',
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfiloScreen()),
                    ).then((_) => _caricaNome());
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

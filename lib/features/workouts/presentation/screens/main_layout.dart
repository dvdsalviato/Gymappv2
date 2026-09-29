import 'package:flutter/material.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  final List<Widget> _pages = [
    const SchedePage(),
    const StoricoPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gymapp, Davide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepOrange),
              child: Text(
                'Gymapp',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            SwitchListTile(
              title: const Text('Tema scuro'),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: _isDarkMode,
              onChanged: (val) => setState(() => _isDarkMode = val),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Il mio profilo'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Calendario presenze'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.accessibility_new_outlined),
              title: const Text('Mappa muscolare'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('Assistente AI'),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Schede',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Storico',
          ),
        ],
      ),
    );
  }
}

class SchedePage extends StatelessWidget {
  const SchedePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: [
          const Text(
            'Schede',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Le tue schede di allenamento',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('test', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.qr_code, size: 20), onPressed: () {}),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () {}),
                        ],
                      ),
                    ],
                  ),
                  const Text('1 esercizi', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            shape: StadiumBorder(),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Inizia'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {},
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Nuova scheda', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class StoricoPage extends StatelessWidget {
  const StoricoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAlignment.start,
        children: const [
          Text(
            'Storico',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(
            'I tuoi allenamenti, per scheda ed esercizio',
            style: TextStyle(color: Colors.grey),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Nessuna serie registrata ancora.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

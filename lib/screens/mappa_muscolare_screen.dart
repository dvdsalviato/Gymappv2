import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

class MappaMuscolareScreen extends StatefulWidget {
  const MappaMuscolareScreen({super.key});

  @override
  State<MappaMuscolareScreen> createState() => _MappaMuscolareScreenState();
}

class _MappaMuscolareScreenState extends State<MappaMuscolareScreen> {
  bool _retro = false;
  bool _loading = true;
  Map<String, int> _volumi = {};

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final volumi = await DatabaseHelper.instance.getVolumePerCategoria(giorni: 7);
    setState(() {
      _volumi = volumi;
      _loading = false;
    });
  }

  Color _coloreVolume(String categoria) {
    final n = _volumi[categoria] ?? 0;
    if (n == 0) return const Color(0xFFBDBDBD); // grigio: a riposo
    if (n <= 8) return const Color(0xFF4CAF50); // verde: mantenimento
    if (n <= 18) return const Color(0xFFFFA726); // arancione: volume ottimale
    return const Color(0xFFE53935); // rosso: alto volume
  }

  Widget _regione(String categoria, {double width = 70, double height = 70, BorderRadiusGeometry? radius}) {
    final n = _volumi[categoria] ?? 0;
    return Tooltip(
      message: '$categoria: $n serie negli ultimi 7 giorni',
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _coloreVolume(categoria),
          borderRadius: radius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _corpoFronte() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // testa
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFBDBDBD), shape: BoxShape.circle)),
        const SizedBox(height: 6),
        // spalle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _regione('Spalle', width: 36, height: 36, radius: BorderRadius.circular(18)),
            const SizedBox(width: 68),
            _regione('Spalle', width: 36, height: 36, radius: BorderRadius.circular(18)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // braccio sx (bicipiti visti di fronte)
            _regione('Bicipiti', width: 26, height: 90, radius: BorderRadius.circular(10)),
            const SizedBox(width: 6),
            // petto + core
            Column(
              children: [
                _regione('Petto', width: 96, height: 55, radius: BorderRadius.circular(12)),
                const SizedBox(height: 4),
                _regione('Core', width: 76, height: 55, radius: BorderRadius.circular(10)),
              ],
            ),
            const SizedBox(width: 6),
            _regione('Bicipiti', width: 26, height: 90, radius: BorderRadius.circular(10)),
          ],
        ),
        const SizedBox(height: 6),
        _regione('Gambe', width: 140, height: 130, radius: BorderRadius.circular(14)),
      ],
    );
  }

  Widget _corpoRetro() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFBDBDBD), shape: BoxShape.circle)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _regione('Spalle', width: 36, height: 36, radius: BorderRadius.circular(18)),
            const SizedBox(width: 68),
            _regione('Spalle', width: 36, height: 36, radius: BorderRadius.circular(18)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // braccio sx (tricipiti visti da dietro)
            _regione('Tricipiti', width: 26, height: 90, radius: BorderRadius.circular(10)),
            const SizedBox(width: 6),
            _regione('Schiena', width: 96, height: 110, radius: BorderRadius.circular(12)),
            const SizedBox(width: 6),
            _regione('Tricipiti', width: 26, height: 90, radius: BorderRadius.circular(10)),
          ],
        ),
        const SizedBox(height: 6),
        _regione('Gambe', width: 140, height: 130, radius: BorderRadius.circular(14)),
      ],
    );
  }

  Widget _legenda() {
    final voci = [
      ('Grigio', 'A riposo (0 serie)', const Color(0xFFBDBDBD)),
      ('Verde', 'Mantenimento (1-8)', const Color(0xFF4CAF50)),
      ('Arancione', 'Volume ottimale (9-18)', const Color(0xFFFFA726)),
      ('Rosso', 'Alto volume (>18)', const Color(0xFFE53935)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: voci.map((v) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(width: 16, height: 16, decoration: BoxDecoration(color: v.$3, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text(v.$2, style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mappa muscolare')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Volume di lavoro degli ultimi 7 giorni',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 20),
                    ToggleButtons(
                      isSelected: [!_retro, _retro],
                      onPressed: (i) => setState(() => _retro = i == 1),
                      borderRadius: BorderRadius.circular(20),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Fronte')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Retro')),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _retro ? _corpoRetro() : _corpoFronte(),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: coloreCard(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Legenda', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _legenda(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

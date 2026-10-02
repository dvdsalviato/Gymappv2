import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';

class CalendarioScreen extends StatefulWidget {
  const CalendarioScreen({super.key});

  @override
  State<CalendarioScreen> createState() => _CalendarioScreenState();
}

class _CalendarioScreenState extends State<CalendarioScreen> {
  DateTime _mese = DateTime(DateTime.now().year, DateTime.now().month);
  Set<DateTime> _giorni = {};
  bool _loading = true;

  static const _nomiMesi = [
    'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
    'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre',
  ];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final giorni = await DatabaseHelper.instance.getGiorniPresenza();
    setState(() {
      _giorni = giorni;
      _loading = false;
    });
  }

  void _mesePrecedente() => setState(() => _mese = DateTime(_mese.year, _mese.month - 1));
  void _meseSuccessivo() => setState(() => _mese = DateTime(_mese.year, _mese.month + 1));

  bool _presente(DateTime giorno) => _giorni.any(
        (d) => d.year == giorno.year && d.month == giorno.month && d.day == giorno.day,
      );

  @override
  Widget build(BuildContext context) {
    final primoGiorno = DateTime(_mese.year, _mese.month, 1);
    final giorniNelMese = DateTime(_mese.year, _mese.month + 1, 0).day;
    final offset = (primoGiorno.weekday - 1) % 7; // lunedì = colonna 0

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario presenze')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(onPressed: _mesePrecedente, icon: const Icon(Icons.chevron_left)),
                        Text(
                          '${_nomiMesi[_mese.month - 1]} ${_mese.year}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(onPressed: _meseSuccessivo, icon: const Icon(Icons.chevron_right)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                          .map(
                            (g) => Expanded(
                              child: Center(
                                child: Text(
                                  g,
                                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: offset + giorniNelMese,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                      itemBuilder: (context, index) {
                        if (index < offset) return const SizedBox.shrink();
                        final giorno = index - offset + 1;
                        final data = DateTime(_mese.year, _mese.month, giorno);
                        final presente = _presente(data);
                        return Padding(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: presente ? AppColors.accento : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$giorno',
                              style: TextStyle(
                                color: presente ? Colors.black : null,
                                fontWeight: presente ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${_giorni.length} giorni totali in palestra',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../theme/app_theme.dart';
import 'edit_esercizio_screen.dart';

class SchedaEditorScreen extends StatefulWidget {
  final Scheda scheda;

  const SchedaEditorScreen({super.key, required this.scheda});

  @override
  State<SchedaEditorScreen> createState() => _SchedaEditorScreenState();
}

class _SchedaEditorScreenState extends State<SchedaEditorScreen> {
  List<Esercizio> _esercizi = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final lista = await DatabaseHelper.instance.getEsercizi(widget.scheda.id!);
    setState(() {
      _esercizi = lista;
      _loading = false;
    });
  }

  Future<void> _apriModifica([Esercizio? esercizio]) async {
    final prossimoOrdine = _esercizi.isEmpty
        ? 0
        : (_esercizi.map((e) => e.ordine).reduce((a, b) => a > b ? a : b) + 1);
    final risultato = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditEsercizioScreen(
          schedaId: widget.scheda.id!,
          esercizio: esercizio,
          ordineSuggerito: prossimoOrdine,
        ),
      ),
    );
    if (risultato == true) _carica();
  }

  Future<void> _elimina(Esercizio esercizio) async {
    if (esercizio.id == null) return;
    await DatabaseHelper.instance.deleteEsercizio(esercizio.id!);
    _carica();
  }

  Future<void> _riordina(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final voce = _esercizi.removeAt(oldIndex);
      _esercizi.insert(newIndex, voce);
    });
    // Salva il nuovo ordine nel database.
    for (int i = 0; i < _esercizi.length; i++) {
      final e = _esercizi[i];
      if (e.ordine != i) {
        await DatabaseHelper.instance.updateEsercizio(
          Esercizio(
            id: e.id,
            schedaId: e.schedaId,
            nome: e.nome,
            ordine: i,
            serieTotali: e.serieTotali,
            repTarget: e.repTarget,
            riposoSecondi: e.riposoSecondi,
            note: e.note,
            categoria: e.categoria,
            aTempo: e.aTempo,
          ),
        );
      }
    }
    await _carica();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.scheda.nome)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _esercizi.isEmpty
                  ? Center(
                      child: Text(
                        'Nessun esercizio in questa scheda.\nPremi + per aggiungerne uno.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Tieni premuta la maniglia per riordinare',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: _esercizi.length,
                            onReorder: _riordina,
                            itemBuilder: (context, index) {
                              final e = _esercizi[index];
                              return Dismissible(
                                key: ValueKey(e.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.delete, color: Colors.red),
                                ),
                                onDismissed: (_) => _elimina(e),
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: coloreCard(context),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Icon(Icons.drag_handle, color: Colors.grey.shade400),
                                          ),
                                        ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _apriModifica(e),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  e.nome,
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  e.aTempo
                                                      ? '${e.serieTotali} serie x ${formattaDurata(e.repTarget)} · riposo ${e.riposoSecondi}s'
                                                      : '${e.serieTotali} serie x ${e.repTarget} rep · riposo ${e.riposoSecondi}s',
                                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                ),
                                                if (e.note != null && e.note!.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '📝 ${e.note}',
                                                    style: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 12,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _apriModifica(),
        backgroundColor: AppColors.accento,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}

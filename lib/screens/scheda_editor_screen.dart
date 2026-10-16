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

  /// Un superset ha senso solo con almeno due esercizi di fila: se ne resta
  /// uno solo (perché hai eliminato o spostato un compagno) lo tolgo dal gruppo.
  Future<bool> _riparaSuperset(List<Esercizio> lista) async {
    var cambiato = false;
    var i = 0;
    while (i < lista.length) {
      final id = lista[i].supersetId;
      var j = i;
      while (j + 1 < lista.length && lista[j + 1].supersetId == id) {
        j++;
      }
      if (id != 0 && j == i && lista[i].id != null) {
        await DatabaseHelper.instance.setSuperset(lista[i].id!, 0);
        cambiato = true;
      }
      i = j + 1;
    }
    return cambiato;
  }

  /// Collega l'esercizio in posizione [i] al successivo (o li scollega).
  Future<void> _toggleSuperset(int i) async {
    final a = _esercizi[i];
    final b = _esercizi[i + 1];
    if (a.id == null || b.id == null) return;
    final db = DatabaseHelper.instance;
    var massimo = 0;
    for (final e in _esercizi) {
      if (e.supersetId > massimo) massimo = e.supersetId;
    }
    if (a.supersetId != 0 && a.supersetId == b.supersetId) {
      // Scollega: la parte dopo il taglio diventa un gruppo a sé (o nessuno).
      final id = a.supersetId;
      var fine = i + 1;
      while (fine + 1 < _esercizi.length && _esercizi[fine + 1].supersetId == id) {
        fine++;
      }
      var inizio = i;
      while (inizio > 0 && _esercizi[inizio - 1].supersetId == id) {
        inizio--;
      }
      final testa = _esercizi.sublist(inizio, i + 1);
      final coda = _esercizi.sublist(i + 1, fine + 1);
      if (testa.length < 2) {
        for (final e in testa) {
          await db.setSuperset(e.id!, 0);
        }
      }
      final idCoda = coda.length < 2 ? 0 : massimo + 1;
      for (final e in coda) {
        await db.setSuperset(e.id!, idCoda);
      }
    } else {
      // Collega: i due (e i loro eventuali gruppi) diventano un unico superset.
      final alvo = a.supersetId != 0 ? a.supersetId : (b.supersetId != 0 ? b.supersetId : massimo + 1);
      for (final e in _esercizi) {
        final inGruppo = (a.supersetId != 0 && e.supersetId == a.supersetId) ||
            (b.supersetId != 0 && e.supersetId == b.supersetId) ||
            e.id == a.id ||
            e.id == b.id;
        if (inGruppo && e.id != null) await db.setSuperset(e.id!, alvo);
      }
    }
    await _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    var lista = await DatabaseHelper.instance.getEsercizi(widget.scheda.id!);
    if (await _riparaSuperset(lista)) {
      lista = await DatabaseHelper.instance.getEsercizi(widget.scheda.id!);
    }
    if (!mounted) return;
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
                            'Tieni premuta la maniglia per riordinare · usa il collegamento per creare un superset',
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
                                                if (e.supersetId != 0)
                                                  const Text(
                                                    'SUPERSET',
                                                    style: TextStyle(
                                                      color: AppColors.accento,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11,
                                                      letterSpacing: 1.3,
                                                    ),
                                                  ),
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
                                        if (index < _esercizi.length - 1)
                                          IconButton(
                                            tooltip: (e.supersetId != 0 && e.supersetId == _esercizi[index + 1].supersetId)
                                                ? 'Scollega dal successivo'
                                                : 'Collega al successivo in superset',
                                            onPressed: () => _toggleSuperset(index),
                                            icon: Icon(
                                              (e.supersetId != 0 && e.supersetId == _esercizi[index + 1].supersetId)
                                                  ? Icons.link
                                                  : Icons.link_off,
                                              color: (e.supersetId != 0 && e.supersetId == _esercizi[index + 1].supersetId)
                                                  ? AppColors.accento
                                                  : Colors.grey.shade400,
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

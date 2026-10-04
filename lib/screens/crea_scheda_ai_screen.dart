import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/catalogo_esercizi.dart';
import '../data/tempo.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../services/condivisione_scheda.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';
import 'assistente_screen.dart';

const _focusDisponibili = ['Full body', 'Push', 'Pull', 'Gambe', 'Upper', 'Lower', 'Petto e tricipiti', 'Schiena e bicipiti'];
const _obiettiviDisponibili = ['Massa muscolare', 'Forza', 'Dimagrimento', 'Mantenimento'];
const _livelliDisponibili = ['Principiante', 'Intermedio', 'Avanzato'];
const _durateDisponibili = [45, 60, 75, 90];

/// Fa creare una scheda a Gemini e la importa nell'app.
class CreaSchedaAiScreen extends StatefulWidget {
  const CreaSchedaAiScreen({super.key});

  @override
  State<CreaSchedaAiScreen> createState() => _CreaSchedaAiScreenState();
}

class _CreaSchedaAiScreenState extends State<CreaSchedaAiScreen> {
  String? _apiKey;
  bool _caricamentoChiave = true;

  String _focus = 'Full body';
  String _obiettivo = 'Massa muscolare';
  String _livello = 'Intermedio';
  int _durata = 60;
  final _noteCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();

  bool _generando = false;
  String? _errore;
  List<Esercizio>? _risultato;

  @override
  void initState() {
    super.initState();
    _leggiChiave();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _leggiChiave() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
      _caricamentoChiave = false;
    });
  }

  String _istruzioniSistema() {
    final perCategoria = <String, List<String>>{};
    for (final e in catalogoEsercizi) {
      perCategoria.putIfAbsent(e.categoria, () => []).add(e.nome);
    }
    final elenco = perCategoria.entries.map((e) => '${e.key}: ${e.value.join('; ')}').join('\n');
    return [
      'Sei un personal trainer esperto. Crei la scheda per UNA sola sessione di allenamento.',
      'Rispondi SOLO con un oggetto JSON valido, senza testo prima o dopo e senza markdown, in questa forma esatta:',
      '{"nome": "Nome scheda", "esercizi": [{"nome": "...", "serie": 3, "rep": 10, "riposo": 90, "nota": "..."}]}',
      'Regole: usa SOLO nomi di esercizi presi ESATTAMENTE dall\'elenco sotto. Da 5 a 9 esercizi, in ordine di esecuzione (prima i multiarticolari).',
      '"serie" da 2 a 5, "rep" da 5 a 20, "riposo" in secondi da 45 a 180, "nota" facoltativa (massimo 60 caratteri).',
      'Per gli esercizi a tempo (cardio, plank) usa "tempo": true e "durata" in secondi al posto di "rep".',
      'Adatta volume e scelta degli esercizi a livello, obiettivo e durata indicati.',
      'Elenco esercizi disponibili, per categoria:',
      elenco,
    ].join('\n');
  }

  Future<String> _descrizioneProfilo() async {
    final p = await DatabaseHelper.instance.getProfilo();
    if (p == null) return '';
    final parti = <String>[];
    if (p['eta'] != null) parti.add('età ${p['eta']}');
    if ((p['sesso'] as String?)?.isNotEmpty ?? false) parti.add('sesso ${p['sesso']}');
    if (p['peso_kg'] != null) parti.add('peso ${p['peso_kg']} kg');
    if (p['altezza_cm'] != null) parti.add('altezza ${p['altezza_cm']} cm');
    return parti.isEmpty ? '' : 'Dati dell\'utente: ${parti.join(', ')}.';
  }

  EsercizioCatalogo? _trovaNelCatalogo(String nome) {
    final n = nome.trim().toLowerCase();
    for (final e in catalogoEsercizi) {
      if (e.nome.toLowerCase() == n) return e;
    }
    for (final e in catalogoEsercizi) {
      final c = e.nome.toLowerCase();
      if (c.contains(n) || n.contains(c)) return e;
    }
    return null;
  }

  int _intLimitato(dynamic v, int min, int max, int predefinito) {
    final n = v is num ? v.round() : int.tryParse('$v');
    if (n == null) return predefinito;
    if (n < min) return min;
    if (n > max) return max;
    return n;
  }

  Map<String, dynamic>? _estraiJson(String testo) {
    final inizio = testo.indexOf('{');
    final fine = testo.lastIndexOf('}');
    if (inizio < 0 || fine <= inizio) return null;
    try {
      return jsonDecode(testo.substring(inizio, fine + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _genera() async {
    final chiave = _apiKey;
    if (chiave == null) return;
    setState(() {
      _generando = true;
      _errore = null;
      _risultato = null;
    });
    try {
      final profilo = await _descrizioneProfilo();
      final note = _noteCtrl.text.trim();
      final richiesta = [
        'Crea una scheda: focus $_focus, obiettivo $_obiettivo, livello $_livello, durata circa $_durata minuti.',
        if (note.isNotEmpty) 'Indicazioni dell\'utente: $note.',
        if (profilo.isNotEmpty) profilo,
      ].join(' ');

      final risposta = await GeminiService.generaRisposta(
        apiKey: chiave,
        cronologia: [
          {'ruolo': 'user', 'testo': richiesta},
        ],
        istruzioniSistema: _istruzioniSistema(),
      );

      final json = _estraiJson(risposta);
      final voci = json?['esercizi'] as List?;
      if (json == null || voci == null || voci.isEmpty) {
        throw Exception('La risposta non era una scheda valida. Riprova.');
      }
      final esercizi = <Esercizio>[];
      for (final v in voci) {
        if (v is! Map<String, dynamic>) continue;
        final nomeGrezzo = (v['nome'] as String?)?.trim();
        if (nomeGrezzo == null || nomeGrezzo.isEmpty) continue;
        final cat = _trovaNelCatalogo(nomeGrezzo);
        final nota = (v['nota'] as String?)?.trim();
        final predefinita = (cat != null && cat.durataSecondi > 0) ? cat.durataSecondi : 0;
        final aTempo = v['tempo'] == true || (predefinita > 0 && v['rep'] == null);
        final durata = _intLimitato(v['durata'], 10, 3600, predefinita > 0 ? predefinita : 60);
        esercizi.add(Esercizio(
          schedaId: -1,
          nome: cat?.nome ?? nomeGrezzo,
          ordine: esercizi.length,
          serieTotali: _intLimitato(v['serie'], 1, 8, 3),
          repTarget: aTempo ? durata : _intLimitato(v['rep'], 1, 30, 10),
          aTempo: aTempo,
          riposoSecondi: _intLimitato(v['riposo'], 0, 300, 90),
          categoria: cat?.categoria ?? 'Altro',
          note: (nota == null || nota.isEmpty) ? null : nota,
        ));
      }
      if (esercizi.isEmpty) throw Exception('Nessun esercizio valido nella risposta. Riprova.');
      if (!mounted) return;
      setState(() {
        _nomeCtrl.text = ((json['nome'] as String?)?.trim().isNotEmpty ?? false)
            ? (json['nome'] as String).trim()
            : '$_focus AI';
        _risultato = esercizi;
        _generando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString().replaceFirst('Exception: ', '');
        _generando = false;
      });
    }
  }

  Future<void> _importa() async {
    final esercizi = _risultato;
    if (esercizi == null || esercizi.isEmpty) return;
    final nome = _nomeCtrl.text.trim().isEmpty ? '$_focus AI' : _nomeCtrl.text.trim();
    final importata = SchedaImportata(nome, esercizi);
    final schedaId = await DatabaseHelper.instance.insertScheda(
      Scheda(nome: importata.nome, dataCreazione: DateTime.now().toIso8601String()),
    );
    for (var i = 0; i < importata.esercizi.length; i++) {
      final e = importata.esercizi[i];
      await DatabaseHelper.instance.insertEsercizio(
        Esercizio(
          schedaId: schedaId,
          nome: e.nome,
          ordine: i,
          serieTotali: e.serieTotali,
          repTarget: e.repTarget,
          riposoSecondi: e.riposoSecondi,
          categoria: e.categoria,
          note: e.note,
          aTempo: e.aTempo,
        ),
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Scheda "$nome" importata')));
    Navigator.pop(context, true);
  }

  Widget _titolo(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          t,
          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.4),
        ),
      );

  Widget _scelta<T>(List<T> valori, T selezionato, ValueChanged<T> onCambia, {String Function(T)? etichetta}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in valori)
          ChoiceChip(
            label: Text(etichetta != null ? etichetta(v) : '$v'),
            selected: v == selezionato,
            selectedColor: AppColors.accento,
            labelStyle: TextStyle(
              color: v == selezionato ? Colors.black : null,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => onCambia(v),
          ),
      ],
    );
  }

  Widget _senzaChiave() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.key, size: 48, color: AppColors.accento),
          const SizedBox(height: 16),
          Text(
            'Serve la chiave Gemini',
            style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'La stessa dell\'Assistente AI: inseriscila lì una volta sola e torna qui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistenteScreen()));
              _leggiChiave();
            },
            child: const Text('Apri Assistente AI'),
          ),
        ],
      ),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titolo('FOCUS'),
          _scelta<String>(_focusDisponibili, _focus, (v) => setState(() => _focus = v)),
          _titolo('OBIETTIVO'),
          _scelta<String>(_obiettiviDisponibili, _obiettivo, (v) => setState(() => _obiettivo = v)),
          _titolo('LIVELLO'),
          _scelta<String>(_livelliDisponibili, _livello, (v) => setState(() => _livello = v)),
          _titolo('DURATA'),
          _scelta<int>(_durateDisponibili, _durata, (v) => setState(() => _durata = v), etichetta: (v) => '$v min'),
          _titolo('NOTE (FACOLTATIVO)'),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'es. niente squat, ho solo manubri...'),
          ),
          const SizedBox(height: 22),
          if (_errore != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(_errore!, style: const TextStyle(fontSize: 13)),
            ),
          FilledButton.icon(
            onPressed: _generando ? null : _genera,
            icon: _generando
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.auto_awesome),
            label: Text(_generando ? 'Sto creando la scheda...' : 'Crea scheda'),
          ),
          const SizedBox(height: 10),
          Text(
            'La richiesta (e i tuoi dati di profilo, se compilati) viene inviata a Google Gemini. Suggerimenti generali, non sostituiscono un professionista.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _anteprima(List<Esercizio> esercizi) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _titolo('NOME DELLA SCHEDA'),
          TextField(controller: _nomeCtrl),
          _titolo('ESERCIZI (TOCCA LA X PER TOGLIERNE UNO)'),
          for (var i = 0; i < esercizi.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              decoration: BoxDecoration(
                color: coloreSuperficie(context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(esercizi[i].nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${esercizi[i].serieTotali} x ${esercizi[i].aTempo ? formattaDurata(esercizi[i].repTarget) : '${esercizi[i].repTarget}'} · riposo ${esercizi[i].riposoSecondi}s · ${esercizi[i].categoria}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                        if (esercizi[i].note != null)
                          Text(esercizi[i].note!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _risultato = [...esercizi]..removeAt(i)),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: esercizi.isEmpty ? null : _importa,
            icon: const Icon(Icons.download_done),
            label: const Text('Importa scheda'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => _risultato = null),
            icon: const Icon(Icons.refresh),
            label: const Text('Cambia richiesta'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const StadiumBorder()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (_caricamentoChiave) {
      corpo = const Center(child: CircularProgressIndicator());
    } else if (_apiKey == null) {
      corpo = _senzaChiave();
    } else if (_risultato != null) {
      corpo = _anteprima(_risultato!);
    } else {
      corpo = _form();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scheda con AI')),
      body: SafeArea(child: corpo),
    );
  }
}

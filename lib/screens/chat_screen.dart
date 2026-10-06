import 'dart:async';
import 'package:flutter/material.dart';
import '../amici/amici_servizio.dart';
import '../amici/firestore_rest.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../services/condivisione_scheda.dart';
import '../services/importa_scheda.dart';
import '../theme/app_theme.dart';

/// Chat con un amico. I messaggi si aggiornano ogni pochi secondi mentre la
/// schermata è aperta.
class ChatScreen extends StatefulWidget {
  final Amicizia amicizia;
  const ChatScreen({super.key, required this.amicizia});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final AmiciServizio _servizio = AmiciServizio.istanza;
  final TextEditingController _ctrl = TextEditingController();
  final Map<String, Messaggio> _messaggi = {};

  Timer? _timer;
  String? _mioUid;
  bool _caricato = false;
  bool _inAggiornamento = false;
  bool _invio = false;
  String? _errore;
  int _ultimoTs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _avvia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _avviaTimer();
      _aggiorna();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _avviaTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _aggiorna());
  }

  Future<void> _avvia() async {
    try {
      final p = await _servizio.profiloLocale();
      _mioUid = p?.uid;
      final iniziali = await _servizio.ultimiMessaggi(widget.amicizia.id);
      for (final m in iniziali) {
        _messaggi[m.id] = m;
        if (m.ts > _ultimoTs) _ultimoTs = m.ts;
      }
      await _servizio.segnaLetto(widget.amicizia.id, _ultimoTs);
      if (!mounted) return;
      setState(() => _caricato = true);
      _avviaTimer();
    } on AmiciErrore catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricato = true;
      });
    }
  }

  Future<void> _aggiorna() async {
    if (_inAggiornamento || !mounted || !_caricato || _errore != null) return;
    _inAggiornamento = true;
    try {
      final nuovi = await _servizio.nuoviMessaggi(widget.amicizia.id, _ultimoTs);
      var cambiato = false;
      for (final m in nuovi) {
        if (!_messaggi.containsKey(m.id)) {
          _messaggi[m.id] = m;
          cambiato = true;
        }
        if (m.ts > _ultimoTs) _ultimoTs = m.ts;
      }
      if (cambiato) {
        await _servizio.segnaLetto(widget.amicizia.id, _ultimoTs);
        if (mounted) setState(() {});
      }
    } catch (_) {
      // un errore di rete momentaneo non interrompe la chat
    } finally {
      _inAggiornamento = false;
    }
  }

  void _avviso(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _invia({String? testo, String tipo = 'testo', String payload = ''}) async {
    final contenuto = (testo ?? _ctrl.text).trim();
    if (contenuto.isEmpty || _invio) return;
    setState(() => _invio = true);
    try {
      await _servizio.inviaMessaggio(widget.amicizia.id, contenuto, tipo: tipo, payload: payload);
      if (testo == null) _ctrl.clear();
      await _aggiorna();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    }
    if (mounted) setState(() => _invio = false);
  }

  Future<void> _condividiScheda() async {
    final schede = await DatabaseHelper.instance.getSchede();
    if (!mounted) return;
    if (schede.isEmpty) {
      _avviso('Non hai ancora schede da condividere.');
      return;
    }
    final scelta = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quale scheda vuoi condividere?'),
        children: [
          for (var i = 0; i < schede.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(schede[i].nome, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
    if (scelta == null) return;
    final s = schede[scelta];
    final id = s.id;
    if (id == null) return;
    final esercizi = await DatabaseHelper.instance.getEsercizi(id);
    await _invia(testo: s.nome, tipo: 'scheda', payload: codificaScheda(s.nome, esercizi));
  }

  Future<void> _condividiProgressi() async {
    final stat = await caricaStatistiche();
    final volumi = await DatabaseHelper.instance.getVolumePerCategoria(giorni: 7);
    final serie7 = volumi.values.fold<int>(0, (a, b) => a + b);
    final testo = '📈 I miei progressi\n'
        'Allenamenti: ${stat.allenamenti} · Serie: ${stat.serie}\n'
        'Settimane di fila: ${stat.settimane}\n'
        'Questa settimana: ${stat.allenamentiSettimana}/${stat.obiettivo} allenamenti, $serie7 serie';
    await _invia(testo: testo, tipo: 'progressi');
  }

  void _menuAllega() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.assignment_outlined, color: AppColors.accento),
                title: const Text('Condividi una scheda'),
                onTap: () {
                  Navigator.pop(ctx);
                  _condividiScheda();
                },
              ),
              ListTile(
                leading: const Icon(Icons.trending_up, color: AppColors.accento),
                title: const Text('Condividi i miei progressi'),
                onTap: () {
                  Navigator.pop(ctx);
                  _condividiProgressi();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importa(String payload) async {
    final d = decodificaScheda(payload);
    if (d == null) {
      _avviso('Scheda non valida.');
      return;
    }
    await salvaSchedaImportata(d);
    _avviso('Scheda "${d.nome}" importata');
  }

  String _ora(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    String due(int n) => n.toString().padLeft(2, '0');
    return '${due(d.hour)}:${due(d.minute)}';
  }

  Widget _bolla(Messaggio m) {
    final mio = m.da == _mioUid;
    final colore = mio ? AppColors.accento : coloreSuperficie(context);
    final testoColore = mio ? Colors.black : null;
    final sottoColore = mio ? Colors.black54 : Colors.grey.shade500;

    final contenuto = <Widget>[];
    if (m.tipo == 'scheda') {
      contenuto.addAll([
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 18, color: testoColore),
            const SizedBox(width: 6),
            Flexible(
              child: Text('Scheda: ${m.testo}', style: TextStyle(fontWeight: FontWeight.w700, color: testoColore)),
            ),
          ],
        ),
        if (!mio) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => _importa(m.payload),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Importa'),
          ),
        ],
      ]);
    } else {
      contenuto.add(Text(m.testo, style: TextStyle(color: testoColore, height: 1.25)));
    }

    return Align(
      alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        decoration: BoxDecoration(
          color: colore,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mio ? 20 : 4),
            bottomRight: Radius.circular(mio ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: contenuto)),
            const SizedBox(height: 2),
            Text(_ora(m.ts), style: TextStyle(fontSize: 10, color: sottoColore)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _messaggi.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
    return Scaffold(
      appBar: AppBar(title: Text(widget.amicizia.nomeAltro)),
      body: Column(
        children: [
          Expanded(
            child: !_caricato
                ? const Center(child: CircularProgressIndicator())
                : _errore != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_errore!, textAlign: TextAlign.center)))
                    : lista.isEmpty
                        ? Center(
                            child: Text(
                              'Nessun messaggio.\nScrivi per primo!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: lista.length,
                            itemBuilder: (context, i) => _bolla(lista[lista.length - 1 - i]),
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: _errore != null ? null : _menuAllega,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Allega',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Scrivi un messaggio...', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: (_errore != null || _invio) ? null : () => _invia(),
                    style: IconButton.styleFrom(backgroundColor: AppColors.accento, foregroundColor: Colors.black),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

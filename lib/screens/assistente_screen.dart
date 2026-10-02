import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class _Messaggio {
  final String ruolo; // 'user' o 'model'
  final String testo;

  _Messaggio(this.ruolo, this.testo);
}

class AssistenteScreen extends StatefulWidget {
  const AssistenteScreen({super.key});

  @override
  State<AssistenteScreen> createState() => _AssistenteScreenState();
}

class _AssistenteScreenState extends State<AssistenteScreen> {
  static const _chiavePrefs = 'gemini_api_key';

  static const _istruzioniSistema =
      'Sei un personal trainer esperto e pratico. Rispondi sempre in italiano, '
      'in modo breve, diretto e concreto. Dai consigli utili su tecnica, carichi, '
      'volume e recupero. Non sei un medico: se emergono dolori o infortuni, '
      'consiglia di sentire un professionista sanitario.';

  String? _apiKey;
  bool _caricamentoIniziale = true;
  bool _inviando = false;
  final List<_Messaggio> _messaggi = [];
  final _inputCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _caricaChiave();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _apiKeyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _caricaChiave() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString(_chiavePrefs);
      _caricamentoIniziale = false;
    });
  }

  Future<void> _salvaChiave() async {
    final chiave = _apiKeyCtrl.text.trim();
    if (chiave.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chiavePrefs, chiave);
    setState(() => _apiKey = chiave);
  }

  Future<void> _cambiaChiave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chiavePrefs);
    setState(() {
      _apiKey = null;
      _messaggi.clear();
    });
  }

  void _scorriGiu() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _inviaMessaggio(String testo) async {
    if (testo.trim().isEmpty || _apiKey == null) return;
    setState(() {
      _messaggi.add(_Messaggio('user', testo.trim()));
      _inviando = true;
    });
    _scorriGiu();

    try {
      final cronologia = _messaggi.map((m) => {'ruolo': m.ruolo, 'testo': m.testo}).toList();
      final risposta = await GeminiService.generaRisposta(
        apiKey: _apiKey!,
        cronologia: cronologia,
        istruzioniSistema: _istruzioniSistema,
      );
      setState(() => _messaggi.add(_Messaggio('model', risposta)));
    } catch (e) {
      setState(() => _messaggi.add(
            _Messaggio('model', '⚠️ ${e.toString().replaceFirst('Exception: ', '')}'),
          ));
    } finally {
      setState(() => _inviando = false);
      _scorriGiu();
    }
  }

  Future<void> _commentaAllenamentoOggi() async {
    final voci = await DatabaseHelper.instance.getStoricoOggi();
    if (voci.isEmpty) {
      setState(() {
        _messaggi.add(_Messaggio(
          'model',
          'Non vedo ancora nessuna serie registrata oggi. Fai qualche esercizio e richiedimelo!',
        ));
      });
      _scorriGiu();
      return;
    }
    final righe = voci
        .map((v) => '- ${v['esercizio_nome']}: ${v['carico']} kg x ${v['rep']} rep (scheda ${v['scheda_nome']})')
        .join('\n');
    final prompt = 'Ecco l\'allenamento che ho fatto oggi:\n$righe\n\n'
        'Commentalo: dimmi se secondo te ho caricato troppo o troppo poco su qualche '
        'esercizio, e dammi accorgimenti utili per la prossima volta.';
    await _inviaMessaggio(prompt);
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamentoIniziale) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _apiKey == null ? _buildSetup() : _buildChat();
  }

  Widget _buildSetup() {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente AI')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Serve una chiave API gratuita di Google Gemini per usare l\'assistente.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text('1. Apri Google AI Studio e accedi con un account Google'),
              const SizedBox(height: 6),
              const Text('2. Tocca "Get API key" / "Crea chiave API"'),
              const SizedBox(height: 6),
              const Text('3. Copiala e incollala qui sotto'),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://aistudio.google.com/apikey'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Apri Google AI Studio'),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Chiave API Gemini',
                  hintText: 'Incolla qui la chiave',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _salvaChiave,
                icon: const Icon(Icons.check),
                label: const Text('Salva e continua'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChat() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistente AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.key_off_outlined),
            tooltip: 'Cambia chiave API',
            onPressed: _cambiaChiave,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Consigli generali, non sostituiscono un professionista.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _inviando ? null : _commentaAllenamentoOggi,
                  icon: const Icon(Icons.today),
                  label: const Text('Commenta il mio allenamento di oggi'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _messaggi.isEmpty
                  ? Center(
                      child: Text(
                        'Chiedimi consigli su tecnica, carichi o recupero!',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _messaggi.length,
                      itemBuilder: (context, index) {
                        final m = _messaggi[index];
                        final mio = m.ruolo == 'user';
                        return Align(
                          alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            decoration: BoxDecoration(
                              color: mio ? AppColors.accento : coloreChip(context),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              m.testo,
                              style: TextStyle(color: mio ? Colors.black : null),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (_inviando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      decoration: const InputDecoration(hintText: 'Scrivi un messaggio...'),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _inviando
                        ? null
                        : () {
                            final testo = _inputCtrl.text;
                            _inputCtrl.clear();
                            _inviaMessaggio(testo);
                          },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

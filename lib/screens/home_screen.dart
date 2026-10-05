import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../data/contenuti.dart';
import '../data/medaglie.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import 'assistente_screen.dart';
import 'calendario_screen.dart';
import 'mappa_muscolare_screen.dart';
import 'medaglie_screen.dart';
import 'workout_screen.dart';

class _Notizia {
  final String titolo;
  final String fonte;
  final String link;
  const _Notizia(this.titolo, this.fonte, this.link);
}

class _AppEsterna {
  final String nome;
  final IconData icona;
  final String url;
  const _AppEsterna(this.nome, this.icona, this.url);
}

const _appEsterne = [
  _AppEsterna('Spotify', Icons.headphones, 'https://open.spotify.com'),
  _AppEsterna('YouTube', Icons.play_circle_outline, 'https://www.youtube.com'),
  _AppEsterna('Strava', Icons.directions_run, 'https://www.strava.com'),
  _AppEsterna('MyFitnessPal', Icons.restaurant_menu, 'https://www.myfitnesspal.com'),
];

class _Categoria {
  final String nome;
  final String ricerca;
  const _Categoria(this.nome, this.ricerca);
}

const _categorie = [
  _Categoria('Ricette fit', 'ricette fit proteiche'),
  _Categoria('Consigli', 'consigli allenamento palestra'),
  _Categoria('Esercizi', 'esercizi allenamento tecnica'),
  _Categoria('Notizie', 'fitness allenamento palestra'),
];

String _urlPer(String ricerca) =>
    'https://news.google.com/rss/search?q=${Uri.encodeQueryComponent(ricerca)}&hl=it&gl=IT&ceid=IT:it';

/// Home: panoramica della settimana, timer dell'allenamento, scorciatoie,
/// notizie e collegamenti ad altre app.
class HomeScreen extends StatefulWidget {
  final String? nome;
  final VoidCallback onVaiAlleSchede;

  const HomeScreen({super.key, required this.nome, required this.onVaiAlleSchede});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _tick;
  Set<DateTime> _presenze = {};
  int _serie7 = 0;
  double? _peso;
  double? _deltaPeso;
  StatisticheUtente? _stat;
  int _medaglieSbloccate = 0;
  List<_Notizia> _notizie = [];
  int _categoria = 0;
  final Map<int, List<_Notizia>> _cache = {};
  bool _ricettaAperta = false;
  bool _notizieCaricamento = true;
  bool _notizieErrore = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && GestoreSessione.inizioAllenamento != null) setState(() {});
    });
    _carica();
    _caricaNotizie();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _carica() async {
    final presenze = await DatabaseHelper.instance.getGiorniPresenza();
    final volumi = await DatabaseHelper.instance.getVolumePerCategoria(giorni: 7);
    final pesi = await DatabaseHelper.instance.getPesi();
    final profilo = await DatabaseHelper.instance.getProfilo();
    double? peso;
    double? delta;
    if (pesi.isNotEmpty) {
      peso = (pesi.last['peso_kg'] as num).toDouble();
      if (pesi.length >= 2) {
        delta = peso - (pesi[pesi.length - 2]['peso_kg'] as num).toDouble();
      }
    } else {
      peso = (profilo?['peso_kg'] as num?)?.toDouble();
    }
    final stat = await caricaStatistiche();
    final esito = await aggiornaMedaglie(stat);
    if (!mounted) return;
    setState(() {
      _presenze = presenze;
      _serie7 = volumi.values.fold(0, (a, b) => a + b);
      _peso = peso;
      _deltaPeso = delta;
      _stat = stat;
      _medaglieSbloccate = esito.sbloccate.length;
    });
    if (esito.nuove.isNotEmpty) {
      final testo = esito.nuove.length == 1
          ? '🏅 Nuova medaglia: ${esito.nuove.first.titolo}'
          : '🏅 ${esito.nuove.length} nuove medaglie sbloccate!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
    }
  }

  Future<void> _cambiaObiettivo() async {
    final corrente = _stat?.obiettivo ?? obiettivoPredefinito;
    final scelto = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Allenamenti a settimana'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 1; i <= 7; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: i == corrente,
                selectedColor: AppColors.accento,
                labelStyle: TextStyle(
                  color: i == corrente ? Colors.black : null,
                  fontWeight: FontWeight.w700,
                ),
                onSelected: (_) => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (scelto == null) return;
    await salvaObiettivoSettimanale(scelto);
    await _carica();
  }

  String _decodifica(String s) {
    var t = s.trim();
    if (t.startsWith('<![CDATA[') && t.endsWith(']]>')) {
      t = t.substring(9, t.length - 3);
    }
    return t
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _estrai(String blocco, String tag) {
    final m = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true).firstMatch(blocco);
    return m == null ? '' : _decodifica(m.group(1) ?? '');
  }

  Future<void> _caricaNotizie({bool forza = false}) async {
    final categoria = _categoria;
    final inCache = _cache[categoria];
    if (!forza && inCache != null) {
      setState(() {
        _notizie = inCache;
        _notizieCaricamento = false;
        _notizieErrore = false;
      });
      return;
    }
    setState(() {
      _notizieCaricamento = true;
      _notizieErrore = false;
    });
    try {
      final r = await http
          .get(Uri.parse(_urlPer(_categorie[categoria].ricerca)))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) throw Exception('errore ${r.statusCode}');
      final xml = utf8.decode(r.bodyBytes, allowMalformed: true);
      final lista = <_Notizia>[];
      for (final m in RegExp('<item>(.*?)</item>', dotAll: true).allMatches(xml)) {
        final blocco = m.group(1) ?? '';
        var titolo = _estrai(blocco, 'title');
        final link = _estrai(blocco, 'link');
        final fonte = _estrai(blocco, 'source');
        if (fonte.isNotEmpty && titolo.endsWith(' - $fonte')) {
          titolo = titolo.substring(0, titolo.length - fonte.length - 3);
        }
        if (titolo.isEmpty || link.isEmpty) continue;
        lista.add(_Notizia(titolo, fonte, link));
        if (lista.length >= 5) break;
      }
      if (!mounted) return;
      if (lista.isNotEmpty) _cache[categoria] = lista;
      if (categoria != _categoria) return; // nel frattempo hai cambiato scheda
      setState(() {
        _notizie = lista;
        _notizieCaricamento = false;
        _notizieErrore = lista.isEmpty;
      });
    } catch (_) {
      if (!mounted || categoria != _categoria) return;
      setState(() {
        _notizieCaricamento = false;
        _notizieErrore = true;
      });
    }
  }

  Future<void> _apri(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il collegamento')),
      );
    }
  }

  Future<void> _riprendi() async {
    final sessione = GestoreSessione.inPausa;
    if (sessione == null) return;
    GestoreSessione.inPausa = null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          esercizi: sessione.coda.map((v) => v.esercizio).toList(),
          nomeScheda: sessione.nomeScheda,
          ripresaDa: sessione,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      _carica();
    }
  }

  String _durata(Duration d) {
    String due(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${due(h)}:${due(m)}:${due(s)}' : '${due(m)}:${due(s)}';
  }

  String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  Widget _etichetta(String testo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        testo,
        style: TextStyle(
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _intestazione() {
    final nome = widget.nome;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset('assets/logo.png', width: 58, height: 58, fit: BoxFit.cover),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome != null ? 'CIAO, ${nome.toUpperCase()}' : 'CIAO',
                style: GoogleFonts.oswald(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 0.6),
                overflow: TextOverflow.ellipsis,
              ),
              const Text(
                'Do it better',
                style: TextStyle(color: AppColors.accento, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardAllenamento() {
    final inizio = GestoreSessione.inizioAllenamento;
    final pausa = GestoreSessione.inPausa;
    final inCorso = inizio != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inCorso ? (pausa != null ? 'ALLENAMENTO IN PAUSA' : 'ALLENAMENTO IN CORSO') : 'ALLENAMENTO',
            style: TextStyle(
              color: inCorso ? AppColors.accento : Colors.grey.shade500,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          if (inCorso) ...[
            Text(
              _durata(DateTime.now().difference(inizio)),
              style: GoogleFonts.oswald(fontSize: 56, fontWeight: FontWeight.w700, height: 1.05),
            ),
            if (pausa != null)
              Text(pausa.nomeScheda, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            if (pausa != null)
              FilledButton.icon(
                onPressed: _riprendi,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Riprendi allenamento'),
              ),
          ] else ...[
            Text(
              'Nessun allenamento in corso',
              style: GoogleFonts.oswald(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Scegli una scheda e parti: qui vedrai il tempo trascorso.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onVaiAlleSchede,
              icon: const Icon(Icons.fitness_center),
              label: const Text('Vai alle schede'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _settimana() {
    final oggi = DateTime.now();
    final lunedi = DateTime(oggi.year, oggi.month, oggi.day - (oggi.weekday - 1));
    const nomi = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final d = DateTime(lunedi.year, lunedi.month, lunedi.day + i);
              final presente = _presenze.contains(d);
              final eOggi = d.year == oggi.year && d.month == oggi.month && d.day == oggi.day;
              return Column(
                children: [
                  Text(nomi[i], style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: presente ? AppColors.accento : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: presente
                            ? AppColors.accento
                            : (eOggi ? AppColors.accento : Colors.white.withOpacity(0.12)),
                        width: eOggi ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: presente
                        ? const Icon(Icons.check, size: 20, color: Colors.black)
                        : Text('${d.day}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _tessera(String valore, String etichetta, {String? nota}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: coloreSuperficie(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valore,
              style: GoogleFonts.oswald(fontSize: 30, fontWeight: FontWeight.w700, height: 1.0),
            ),
            const SizedBox(height: 6),
            Text(etichetta, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
            if (nota != null) ...[
              const SizedBox(height: 2),
              Text(nota, style: const TextStyle(color: AppColors.accento, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _panoramica() {
    final oggi = DateTime.now();
    final lunedi = DateTime(oggi.year, oggi.month, oggi.day - (oggi.weekday - 1));
    var allenamentiSettimana = 0;
    for (var i = 0; i < 7; i++) {
      if (_presenze.contains(DateTime(lunedi.year, lunedi.month, lunedi.day + i))) allenamentiSettimana++;
    }
    String? nota;
    final dp = _deltaPeso;
    if (dp != null) nota = '${dp > 0 ? '+' : ''}${_fmt(dp)} kg';
    return Row(
      children: [
        _tessera('$allenamentiSettimana', 'Allenamenti\nquesta settimana'),
        const SizedBox(width: 10),
        _tessera('$_serie7', 'Serie fatte\nultimi 7 giorni'),
        const SizedBox(width: 10),
        _tessera(_peso == null ? '--' : _fmt(_peso!), 'Peso (kg)', nota: nota),
      ],
    );
  }

  Widget _obiettivoCard() {
    final s = _stat;
    if (s == null) return const SizedBox.shrink();
    final fatto = s.allenamentiSettimana;
    final ob = s.obiettivo;
    final progresso = ob == 0 ? 0.0 : (fatto / ob).clamp(0.0, 1.0);
    final mancano = ob - fatto;
    return GestureDetector(
      onTap: _cambiaObiettivo,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: coloreSuperficie(context),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: _AnelloPainter(progresso.toDouble()),
                child: Center(
                  child: Text('$fatto/$ob', style: GoogleFonts.oswald(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OBIETTIVO SETTIMANALE',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mancano <= 0
                        ? 'Obiettivo raggiunto! 🔥'
                        : (mancano == 1 ? 'Ti manca 1 allenamento' : 'Ti mancano $mancano allenamenti'),
                    style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600, height: 1.15),
                  ),
                  const SizedBox(height: 4),
                  Text('Tocca per cambiarlo', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _traguardiCard() {
    final s = _stat;
    if (s == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const MedaglieScreen()));
        if (mounted) _carica();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: coloreSuperficie(context),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
              child: const Icon(Icons.local_fire_department, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.settimane == 0
                        ? 'Inizia la tua serie'
                        : '${s.settimane} ${s.settimane == 1 ? 'settimana' : 'settimane'} di fila',
                    style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    s.settimane == 0 ? 'Raggiungi l\'obiettivo questa settimana' : 'con l\'obiettivo raggiunto',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$_medaglieSbloccate/${medaglie.length}',
                  style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accento),
                ),
                Text('MEDAGLIE', style: TextStyle(color: Colors.grey.shade500, fontSize: 10, letterSpacing: 1.2)),
              ],
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _scorciatoia(IconData icona, String testo, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: coloreSuperficie(context),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
                child: Icon(icona, color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(testo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scorciatoie() {
    return Row(
      children: [
        _scorciatoia(Icons.calendar_month_outlined, 'Calendario', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarioScreen()));
        }),
        const SizedBox(width: 10),
        _scorciatoia(Icons.accessibility_new, 'Mappa muscolare', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MappaMuscolareScreen()));
        }),
        const SizedBox(width: 10),
        _scorciatoia(Icons.smart_toy_outlined, 'Assistente AI', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistenteScreen()));
        }),
      ],
    );
  }

  int get _giornoDellAnno {
    final ora = DateTime.now();
    return ora.difference(DateTime(ora.year, 1, 1)).inDays;
  }

  Widget _consiglioDelGiorno() {
    final testo = consigliDelGiorno[_giornoDellAnno % consigliDelGiorno.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
            child: const Icon(Icons.lightbulb_outline, color: Colors.black, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONSIGLIO DEL GIORNO',
                  style: TextStyle(color: AppColors.accento, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3),
                ),
                const SizedBox(height: 4),
                Text(testo, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ricettaDelGiorno() {
    final r = ricetteFit[(_giornoDellAnno + 3) % ricetteFit.length];
    return GestureDetector(
      onTap: () => setState(() => _ricettaAperta = !_ricettaAperta),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: coloreSuperficie(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
                  child: const Icon(Icons.restaurant_menu, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RICETTA FIT DEL GIORNO',
                        style: TextStyle(color: AppColors.accento, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.3),
                      ),
                      const SizedBox(height: 2),
                      Text(r.titolo, style: GoogleFonts.oswald(fontSize: 19, fontWeight: FontWeight.w600)),
                      Text(r.tipo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(_ricettaAperta ? Icons.expand_less : Icons.expand_more, color: Colors.grey.shade500),
              ],
            ),
            if (_ricettaAperta) ...[
              const SizedBox(height: 14),
              Text('INGREDIENTI', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              for (final ing in r.ingredienti)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('•  $ing'),
                ),
              const SizedBox(height: 12),
              Text('PREPARAZIONE', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              for (var i = 0; i < r.preparazione.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text('${i + 1}.  ${r.preparazione[i]}', style: const TextStyle(height: 1.3)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sceltaCategoria() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _categorie.length; i++)
          ChoiceChip(
            label: Text(_categorie[i].nome),
            selected: i == _categoria,
            selectedColor: AppColors.accento,
            labelStyle: TextStyle(
              color: i == _categoria ? Colors.black : null,
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) {
              if (i == _categoria) return;
              setState(() => _categoria = i);
              _caricaNotizie();
            },
          ),
      ],
    );
  }

  Widget _notizieCard() {
    Widget contenuto;
    if (_notizieCaricamento) {
      contenuto = const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      );
    } else if (_notizieErrore) {
      contenuto = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Impossibile caricare le notizie (serve internet).',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
            TextButton(onPressed: () => _caricaNotizie(forza: true), child: const Text('Riprova')),
          ],
        ),
      );
    } else {
      contenuto = Column(
        children: [
          for (var i = 0; i < _notizie.length; i++) ...[
            InkWell(
              onTap: () => _apri(_notizie[i].link),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _notizie[i].titolo,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, height: 1.25),
                          ),
                          if (_notizie[i].fonte.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _notizie[i].fonte,
                              style: const TextStyle(color: AppColors.accento, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new, size: 18, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
            if (i < _notizie.length - 1) Divider(height: 1, color: Colors.white.withOpacity(0.07)),
          ],
        ],
      );
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: contenuto,
    );
  }

  Widget _appCollegate() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in _appEsterne)
          GestureDetector(
            onTap: () => _apri(a.url),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: coloreSuperficie(context),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icona, size: 20, color: AppColors.accento),
                  const SizedBox(width: 8),
                  Text(a.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _carica();
        _cache.clear();
        await _caricaNotizie(forza: true);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _intestazione(),
          const SizedBox(height: 18),
          _cardAllenamento(),
          const SizedBox(height: 14),
          _etichetta('QUESTA SETTIMANA'),
          _obiettivoCard(),
          const SizedBox(height: 10),
          _settimana(),
          const SizedBox(height: 10),
          _panoramica(),
          const SizedBox(height: 10),
          _traguardiCard(),
          const SizedBox(height: 14),
          _etichetta('SCORCIATOIE'),
          _scorciatoie(),
          const SizedBox(height: 14),
          _etichetta('OGGI PER TE'),
          _consiglioDelGiorno(),
          const SizedBox(height: 10),
          _ricettaDelGiorno(),
          const SizedBox(height: 14),
          _etichetta('SCOPRI'),
          _sceltaCategoria(),
          const SizedBox(height: 10),
          _notizieCard(),
          const SizedBox(height: 14),
          _etichetta('LE TUE APP'),
          _appCollegate(),
        ],
      ),
    );
  }
}

/// Anello di avanzamento (obiettivo settimanale).
class _AnelloPainter extends CustomPainter {
  final double progresso; // da 0 a 1
  _AnelloPainter(this.progresso);

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);
    final raggio = size.width / 2 - 8;
    final traccia = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(centro, raggio, traccia);
    if (progresso <= 0) return;
    final arco = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accento;
    canvas.drawArc(
      Rect.fromCircle(center: centro, radius: raggio),
      -math.pi / 2,
      2 * math.pi * progresso,
      false,
      arco,
    );
  }

  @override
  bool shouldRepaint(_AnelloPainter old) => old.progresso != progresso;
}

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/coach.dart';
import '../data/medaglie.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../models/scheda.dart';
import '../services/aggiornamenti.dart';
import '../services/coach_servizio.dart';
import '../services/promemoria.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import 'coach_screen.dart';
import 'calendario_screen.dart';
import 'mappa_muscolare_screen.dart';
import 'medaglie_screen.dart';
import 'workout_screen.dart';
import '../widgets/scelta_modalita.dart';

/// Home: prossimo allenamento, accessi rapidi (calendario, muscoli, coach),
/// consigli del coach e la tua settimana. Essenziale: il dettaglio sta in Progressi.
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
  List<ConsiglioCoach> _consigli = [];
  // Prossima scheda della rotazione (quella dopo l'ultima fatta).
  Scheda? _prossima;
  int _eserciziProssima = 0;
  DateTime? _ultimaProssima;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && GestoreSessione.inizioAllenamento != null) setState(() {});
    });
    _carica();
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

    // Rotazione: si propone la scheda che segue (nel tuo ordine) l'ultima fatta.
    final schede = await DatabaseHelper.instance.getSchede();
    final conteggi = await DatabaseHelper.instance.contaEserciziPerScheda();
    final ultime = await DatabaseHelper.instance.getUltimaSessionePerScheda();
    final valide = schede.where((s) => s.id != null && (conteggi[s.id] ?? 0) > 0).toList();
    Scheda? prossima;
    if (valide.isNotEmpty) {
      var indiceUltima = -1;
      DateTime? piuRecente;
      for (var i = 0; i < valide.length; i++) {
        final d = ultime[valide[i].id];
        if (d != null && (piuRecente == null || d.isAfter(piuRecente))) {
          piuRecente = d;
          indiceUltima = i;
        }
      }
      prossima = valide[(indiceUltima + 1) % valide.length];
    }

    final consigli = await consigliDelCoach();

    if (!mounted) return;
    setState(() {
      _consigli = consigli;
      _prossima = prossima;
      _eserciziProssima = prossima == null ? 0 : (conteggi[prossima.id] ?? 0);
      _ultimaProssima = prossima == null ? null : ultime[prossima.id];
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

  Future<void> _apriCoach() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachScreen()));
    if (mounted) _carica();
  }

  /// Avvia subito la scheda proposta in Home.
  Future<void> _iniziaProssima() async {
    final scheda = _prossima;
    // Se c'è un allenamento in pausa decide la schermata Schede (riprendere o no).
    if (scheda == null || scheda.id == null || GestoreSessione.inPausa != null) {
      widget.onVaiAlleSchede();
      return;
    }
    final esercizi = await DatabaseHelper.instance.getEsercizi(scheda.id!);
    if (esercizi.isEmpty || !mounted) return;
    await avviaAllenamento(context, esercizi: esercizi, nomeScheda: scheda.nome);
    Promemoria.ripianifica();
    if (mounted) {
      setState(() {});
      _carica();
    }
  }

  String _quando(DateTime? d) {
    if (d == null) return 'mai fatta';
    final oggi = DateTime.now();
    final giorni = DateTime(oggi.year, oggi.month, oggi.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (giorni <= 0) return 'fatta oggi';
    if (giorni == 1) return 'fatta ieri';
    if (giorni < 14) return 'fatta $giorni giorni fa';
    if (giorni < 60) return 'fatta ${giorni ~/ 7} settimane fa';
    return 'fatta ${giorni ~/ 30} mesi fa';
  }

  String _durata(Duration d) {
    String due(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${due(h)}:${due(m)}:${due(s)}' : '${due(m)}:${due(s)}';
  }

  String _fmt(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  /// Banner "nuova versione disponibile".
  Widget _bannerAggiornamento(Aggiornamento a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.accento.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.accento.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update, color: AppColors.accento),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'È disponibile un nuovo aggiornamento (build ${a.build})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => mostraAggiornaApp(context),
            child: const Text('Aggiorna'),
          ),
        ],
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
              Text(
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
      decoration: pannello(context, raggio: 14, bordo: inCorso ? AppColors.accento.withValues(alpha: 0.5) : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            inCorso
                ? (pausa != null ? 'ALLENAMENTO IN PAUSA' : 'ALLENAMENTO IN CORSO')
                : (_prossima != null ? 'PROSSIMO ALLENAMENTO' : 'ALLENAMENTO'),
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
          ] else if (_prossima != null) ...[
            Text(
              _prossima!.nome.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.oswald(fontSize: 38, fontWeight: FontWeight.w700, height: 1.1),
            ),
            Text(
              '${_eserciziProssima == 1 ? '1 esercizio' : '$_eserciziProssima esercizi'} · ${_quando(_ultimaProssima)}',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _iniziaProssima,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Inizia ${_prossima!.nome}', overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: widget.onVaiAlleSchede,
                child: const Text('Scegli un\'altra scheda'),
              ),
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
      decoration: pannello(context),
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
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: presente
                            ? AppColors.accento
                            : (eOggi
                                ? AppColors.accento
                                : (Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.12))),
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
        decoration: pannello(context),
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
              Text(nota, style: TextStyle(color: AppColors.accento, fontSize: 12, fontWeight: FontWeight.w700)),
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
        decoration: pannello(context),
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
        decoration: pannello(context),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accento.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accento.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.local_fire_department, color: AppColors.accento),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(raggioPannello),
          child: Ink(
            height: 96,
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: pannello(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accento.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icona, color: AppColors.accento, size: 20),
                    ),
                    const Spacer(),
                    Icon(Icons.north_east, size: 14, color: Colors.grey.shade600),
                  ],
                ),
                const Spacer(),
                Text(
                  testo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.oswald(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.8),
                ),
              ],
            ),
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
        _scorciatoia(Icons.accessibility_new, 'Muscoli', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const MappaMuscolareScreen()));
        }),
        const SizedBox(width: 10),
        _scorciatoia(Icons.psychology_outlined, 'Coach', _apriCoach),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          _intestazione(),
          const SizedBox(height: 18),
          ValueListenableBuilder<Aggiornamento?>(
            valueListenable: Aggiornamenti.disponibile,
            builder: (context, agg, _) => agg == null ? const SizedBox.shrink() : _bannerAggiornamento(agg),
          ),
          _cardAllenamento(),
          const SizedBox(height: 10),
          _scorciatoie(),
          const SizedBox(height: 18),
          if (_consigli.isNotEmpty) ...[
            TitoloSezione(
              'Il coach',
              padding: EdgeInsets.zero,
              azione: TextButton(
                onPressed: _apriCoach,
                child: Text(_consigli.length > 2 ? 'Tutti (${_consigli.length})' : 'Apri'),
              ),
            ),
            for (final c in _consigli.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CardConsiglio(consiglio: c, compatta: true),
              ),
            const SizedBox(height: 4),
          ],
          const TitoloSezione('Questa settimana', padding: EdgeInsets.only(top: 6, bottom: 10)),
          _obiettivoCard(),
          const SizedBox(height: 10),
          _settimana(),
          const SizedBox(height: 10),
          _panoramica(),
          const SizedBox(height: 10),
          _traguardiCard(),

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
      ..color = Colors.white.withValues(alpha: 0.08);
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

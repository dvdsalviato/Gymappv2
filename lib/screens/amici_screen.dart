import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../amici/account_servizio.dart';
import '../amici/amici_servizio.dart';
import '../amici/firebase_config.dart';
import '../amici/firestore_rest.dart';
import '../data/statistiche.dart';
import '../db/database_helper.dart';
import '../theme/app_theme.dart';
import 'account_screen.dart';
import 'amico_screen.dart';

class _VoceClassifica {
  final String nome;
  final int allenamenti;
  final int serie;
  final bool io;
  const _VoceClassifica(this.nome, this.allenamenti, this.serie, this.io);
}

/// Scheda "Amici": il tuo codice, le richieste, la classifica e gli amici.
class AmiciScreen extends StatefulWidget {
  const AmiciScreen({super.key});

  @override
  State<AmiciScreen> createState() => _AmiciScreenState();
}

class _AmiciScreenState extends State<AmiciScreen> {
  final AmiciServizio _servizio = AmiciServizio.istanza;
  final TextEditingController _nomeCtrl = TextEditingController();

  bool _caricamento = true;
  bool _registrando = false;
  String? _errore;
  ProfiloAmici? _profilo;
  List<Amicizia> _amicizie = [];
  Map<String, StatAmico?> _stat = {};
  Map<String, int> _letti = {};
  StatisticheUtente? _mie;
  int _mieSerieSettimana = 0;
  bool _condividiSchede = true;
  bool _googleCollegato = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  void _avviso(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _carica() async {
    if (!firebaseConfigurato) {
      setState(() => _caricamento = false);
      return;
    }
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final profilo = await _servizio.profiloLocale();
      if (profilo == null) {
        final p = await DatabaseHelper.instance.getProfilo();
        if (_nomeCtrl.text.isEmpty) _nomeCtrl.text = ((p?['nome'] as String?) ?? '').trim();
        if (!mounted) return;
        setState(() {
          _profilo = null;
          _caricamento = false;
        });
        return;
      }
      try {
        await _servizio.sincronizzaMieiDati();
      } catch (_) {}
      final lista = await _servizio.amicizie();
      final accettate = lista.where((a) => a.stato == 'accettata').toList();
      final stat = await Future.wait(accettate.map((a) async {
        try {
          return await _servizio.statisticheAmico(a.uidAltro);
        } catch (_) {
          return null;
        }
      }));
      final letti = <String, int>{};
      for (final a in accettate) {
        letti[a.id] = await _servizio.lettoFinoA(a.id);
      }
      final mie = await caricaStatistiche();
      final volumi = await DatabaseHelper.instance.getVolumePerCategoria(giorni: 7);
      final condividi = await _servizio.condividiSchede();
      final account = await AccountServizio.istanza.stato();
      if (!mounted) return;
      setState(() {
        _googleCollegato = account.collegato;
        _profilo = profilo;
        _amicizie = lista;
        _stat = {for (var i = 0; i < accettate.length; i++) accettate[i].id: stat[i]};
        _letti = letti;
        _mie = mie;
        _mieSerieSettimana = volumi.values.fold<int>(0, (a, b) => a + b);
        _condividiSchede = condividi;
        _caricamento = false;
      });
    } on AmiciErrore catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = 'Qualcosa è andato storto: $e';
        _caricamento = false;
      });
    }
  }

  Future<void> _creaProfilo() async {
    setState(() => _registrando = true);
    try {
      await _servizio.registra(_nomeCtrl.text);
      await _carica();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    } catch (e) {
      _avviso('Non sono riuscito a creare il profilo: $e');
    }
    if (mounted) setState(() => _registrando = false);
  }

  Future<void> _aggiungiAmico() async {
    final controller = TextEditingController();
    final codice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aggiungi un amico'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Codice amico (6 caratteri)'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Cerca'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (codice == null || codice.trim().isEmpty) return;
    try {
      final trovato = await _servizio.cercaPerCodice(codice);
      if (trovato == null) {
        _avviso('Codice non trovato.');
        return;
      }
      final uid = trovato['_id'] as String;
      final nome = (trovato['nome'] as String?) ?? 'Amico';
      await _servizio.inviaRichiesta(uid, nome);
      _avviso('Richiesta inviata a $nome.');
      await _carica();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    } catch (e) {
      _avviso('Errore: $e');
    }
  }

  Future<void> _rispondi(Amicizia a, bool accetta) async {
    try {
      if (accetta) {
        await _servizio.accetta(a.id);
      } else {
        await _servizio.rimuovi(a.id);
      }
      await _carica();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    }
  }

  Future<void> _cambiaNome() async {
    final controller = TextEditingController(text: _profilo?.nome ?? '');
    final nuovo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Il tuo nome per gli amici'),
        content: TextField(controller: controller, autofocus: true, maxLength: 30),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nuovo == null || nuovo.trim().isEmpty) return;
    try {
      await _servizio.cambiaNome(nuovo);
      await _carica();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    }
  }

  // ------------------------------------------------------------------- UI

  Widget _etichetta(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          t,
          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.4),
        ),
      );

  Widget _scheda({required Widget child, EdgeInsets? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(28)),
        child: child,
      );

  Widget _nonConfigurato() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('AMICI', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 14),
        _scheda(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.group_add_outlined, color: AppColors.accento, size: 36),
              const SizedBox(height: 12),
              Text('Manca un ultimo passaggio', style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                'Per confrontarti con gli amici serve un piccolo servizio online gratuito (Firebase). '
                'Dopo averlo creato, scrivi la chiave e l\'ID del progetto nel file '
                'lib/amici/firebase_config.dart e ricompila l\'app.',
                style: TextStyle(color: Colors.grey.shade400, height: 1.35),
              ),
              const SizedBox(height: 10),
              Text(
                'Finché non lo fai, il resto dell\'app funziona normalmente.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _registrazione() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('AMICI', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 14),
        _scheda(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Crea il tuo profilo', style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                'Scegli il nome che vedranno i tuoi amici. Riceverai un codice da condividere con loro.',
                style: TextStyle(color: Colors.grey.shade400, height: 1.3),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nomeCtrl,
                maxLength: 30,
                decoration: const InputDecoration(hintText: 'Il tuo nome'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _registrando ? null : _creaProfilo,
                child: Text(_registrando ? 'Un attimo...' : 'Crea profilo'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardCodice() {
    final p = _profilo!;
    return _scheda(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'CIAO, ${p.nome.toUpperCase()}',
                  style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 1.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: _cambiaNome,
                icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade500),
                tooltip: 'Cambia nome',
              ),
            ],
          ),
          const Text('Il tuo codice amico', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                p.codice,
                style: GoogleFonts.oswald(fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: 4, color: AppColors.accento),
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: p.codice));
                  _avviso('Codice copiato');
                },
                icon: const Icon(Icons.copy),
                tooltip: 'Copia codice',
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _aggiungiAmico,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Aggiungi amico'),
          ),
        ],
      ),
    );
  }

  Widget _richieste() {
    final me = _profilo!.uid;
    final ricevute = _amicizie.where((a) => a.stato == 'in_attesa' && a.da != me).toList();
    if (ricevute.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etichetta('RICHIESTE DI AMICIZIA'),
        for (final a in ricevute)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: BoxDecoration(
              color: coloreSuperficie(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.accento.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(a.nomeAltro, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                  onPressed: () => _rispondi(a, false),
                  icon: Icon(Icons.close, color: Colors.grey.shade500),
                  tooltip: 'Rifiuta',
                ),
                IconButton.filled(
                  onPressed: () => _rispondi(a, true),
                  icon: const Icon(Icons.check),
                  tooltip: 'Accetta',
                  style: IconButton.styleFrom(backgroundColor: AppColors.accento, foregroundColor: Colors.black),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _classifica() {
    final mie = _mie;
    if (mie == null) return const SizedBox.shrink();
    final voci = <_VoceClassifica>[
      _VoceClassifica('Tu', mie.allenamentiSettimana, _mieSerieSettimana, true),
    ];
    for (final a in _amicizie.where((a) => a.stato == 'accettata')) {
      final s = _stat[a.id];
      if (s != null) voci.add(_VoceClassifica(a.nomeAltro, s.allenSettimana, s.serieSettimana, false));
    }
    if (voci.length < 2) return const SizedBox.shrink();
    voci.sort((x, y) {
      final c = y.allenamenti.compareTo(x.allenamenti);
      return c != 0 ? c : y.serie.compareTo(x.serie);
    });
    const medaglie = ['🥇', '🥈', '🥉'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etichetta('CLASSIFICA DELLA SETTIMANA'),
        _scheda(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < voci.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text(i < 3 ? medaglie[i] : '${i + 1}.', style: const TextStyle(fontSize: 20)),
                      ),
                      Expanded(
                        child: Text(
                          voci[i].nome,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: voci[i].io ? AppColors.accento : null,
                          ),
                        ),
                      ),
                      Text(
                        '${voci[i].allenamenti} allen. · ${voci[i].serie} serie',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listaAmici() {
    final me = _profilo!.uid;
    final accettate = _amicizie.where((a) => a.stato == 'accettata').toList();
    final inviate = _amicizie.where((a) => a.stato == 'in_attesa' && a.da == me).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etichetta('I TUOI AMICI'),
        if (accettate.isEmpty)
          _scheda(
            child: Text(
              'Non hai ancora amici. Scambiatevi i codici e premi "Aggiungi amico".',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        for (final a in accettate) _tesseraAmico(a, me),
        if (inviate.isNotEmpty) ...[
          _etichetta('RICHIESTE INVIATE'),
          for (final a in inviate)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
              decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(22)),
              child: Row(
                children: [
                  Expanded(child: Text('${a.nomeAltro} · in attesa', style: TextStyle(color: Colors.grey.shade400))),
                  IconButton(
                    onPressed: () => _rispondi(a, false),
                    icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                    tooltip: 'Annulla richiesta',
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _tesseraAmico(Amicizia a, String me) {
    final s = _stat[a.id];
    final letto = _letti[a.id] ?? 0;
    final nonLetto = a.ultimoDa.isNotEmpty && a.ultimoDa != me && a.ultimoTs > letto;
    final sottotitolo = a.ultimoTesto.isNotEmpty
        ? a.ultimoTesto
        : (s == null
            ? 'Statistiche non disponibili'
            : '${s.allenSettimana}/${s.obiettivo} allenamenti questa settimana');
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AmicoScreen(amicizia: a, stat: s)),
        );
        if (mounted) _carica();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
              child: Text(
                a.nomeAltro.isEmpty ? '?' : a.nomeAltro.characters.first.toUpperCase(),
                style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nomeAltro, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(
                    sottotitolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nonLetto ? Colors.white : Colors.grey.shade500,
                      fontWeight: nonLetto ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (nonLetto)
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Widget _impostazioni() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etichetta('PRIVACY'),
        _scheda(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Condividi le mie schede', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      'Gli amici possono vederle e importarle. Le statistiche sono visibili solo agli amici accettati.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _condividiSchede,
                onChanged: (v) async {
                  setState(() => _condividiSchede = v);
                  try {
                    await _servizio.impostaCondividiSchede(v);
                  } on AmiciErrore catch (e) {
                    _avviso(e.messaggio);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!firebaseConfigurato) return _nonConfigurato();
    if (_caricamento) return const Center(child: CircularProgressIndicator());
    if (_errore != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.accento),
            const SizedBox(height: 14),
            Text(_errore!, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: _carica, child: const Text('Riprova')),
          ],
        ),
      );
    }
    if (_profilo == null) return _registrazione();
    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text('AMICI', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 14),
          _cardCodice(),
          if (!_googleCollegato && googleConfigurato) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountScreen()));
                if (mounted) _carica();
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accento.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.accento.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.accento),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Collega il tuo account Google: così non perdi amici e dati se cambi telefono.',
                        style: TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ],
          _richieste(),
          _classifica(),
          _listaAmici(),
          _impostazioni(),
        ],
      ),
    );
  }
}

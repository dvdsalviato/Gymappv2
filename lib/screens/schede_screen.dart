import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/dialogo_azioni.dart';
import 'crea_scheda_ai_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../services/condivisione_scheda.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import 'scanner_qr_screen.dart';
import 'scheda_dettaglio_screen.dart';
import 'workout_screen.dart';

class SchedeScreen extends StatefulWidget {
  const SchedeScreen({super.key});

  @override
  State<SchedeScreen> createState() => _SchedeScreenState();
}

class _SchedeScreenState extends State<SchedeScreen> {
  List<Scheda> _schede = [];
  Map<int, int> _conteggioEsercizi = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _loading = true);
    final lista = await DatabaseHelper.instance.getSchede();
    final conteggi = <int, int>{};
    for (final s in lista) {
      if (s.id != null) {
        conteggi[s.id!] = await DatabaseHelper.instance.contaEsercizi(s.id!);
      }
    }
    setState(() {
      _schede = lista;
      _conteggioEsercizi = conteggi;
      _loading = false;
    });
  }

  Future<void> _nuovaScheda() async {
    final controller = TextEditingController();
    final nome = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuova scheda'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nome scheda'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crea'),
          ),
        ],
      ),
    );
    if (nome == null || nome.isEmpty) return;
    await DatabaseHelper.instance.insertScheda(
      Scheda(nome: nome, dataCreazione: DateTime.now().toIso8601String()),
    );
    _carica();
  }

  Future<void> _eliminaScheda(Scheda scheda) async {
    if (scheda.id == null) return;
    final conferma = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminare la scheda?'),
        content: Text(
          'Verranno eliminati anche tutti gli esercizi e lo storico di "${scheda.nome}".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Elimina')),
        ],
      ),
    );
    if (conferma != true) return;
    await DatabaseHelper.instance.deleteScheda(scheda.id!);
    _carica();
  }

  /// Tocco sulla scheda: si apre il dettaglio, da cui si può modificare,
  /// duplicare, condividere, eliminare o iniziare l'allenamento.
  Future<void> _apriDettaglio(Scheda scheda) async {
    final azione = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => SchedaDettaglioScreen(scheda: scheda)),
    );
    await _carica();
    if (!mounted) return;
    if (azione == 'inizia') {
      await _iniziaAllenamento(scheda);
    } else if (azione == 'condividi') {
      await _condividiScheda(scheda);
    } else if (azione == 'elimina') {
      await _eliminaScheda(scheda);
    } else if (azione == 'duplicata') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheda duplicata: la trovi in fondo all\'elenco')),
      );
    }
  }

  Future<void> _iniziaAllenamento(Scheda scheda) async {
    if (scheda.id == null) return;
    final esercizi = await DatabaseHelper.instance.getEsercizi(scheda.id!);
    if (esercizi.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aggiungi almeno un esercizio a questa scheda')),
        );
      }
      return;
    }
    // C'è già un allenamento in pausa: chiedi prima di sostituirlo.
    final inPausa = GestoreSessione.inPausa;
    if (inPausa != null) {
      if (!mounted) return;
      final scelta = await mostraDialogoAzioni<String>(
        context,
        titolo: 'Hai già un allenamento in corso',
        messaggio:
            '"${inPausa.nomeScheda}" è in pausa. Vuoi riprenderlo oppure interromperlo per iniziare "${scheda.nome}"?',
        chiudibile: true,
        azioni: const [
          AzioneDialogo('Riprendi', Icons.play_arrow, 'riprendi', stile: StileAzione.primaria),
          AzioneDialogo('Interrompi e inizia', Icons.stop_circle_outlined, 'nuovo', stile: StileAzione.pericolo),
          AzioneDialogo('Annulla', Icons.arrow_back, 'annulla'),
        ],
      );
      if (scelta == 'riprendi') {
        await _riprendiAllenamento();
        return;
      }
      if (scelta != 'nuovo') return;
    }
    GestoreSessione.inPausa = null;
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutScreen(esercizi: esercizi, nomeScheda: scheda.nome),
        ),
      );
      if (mounted) setState(() {});
    }
  }

  Future<void> _riprendiAllenamento() async {
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
    if (mounted) setState(() {});
  }

  Future<void> _condividiScheda(Scheda scheda) async {
    if (scheda.id == null) return;
    final esercizi = await DatabaseHelper.instance.getEsercizi(scheda.id!);
    if (esercizi.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aggiungi almeno un esercizio prima di condividere')),
        );
      }
      return;
    }
    final testo = codificaScheda(scheda.nome, esercizi);
    if (testo.length > 2000) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheda troppo grande per un QR: prova a dividerla in più schede')),
        );
      }
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Condividi "${scheda.nome}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Fai inquadrare questo QR dall\'altra persona, dalla voce "Importa da QR"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              height: 240,
              child: QrImageView(data: testo, size: 240),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
        ],
      ),
    );
  }

  Future<void> _creaConAi() async {
    final creata = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreaSchedaAiScreen()),
    );
    if (creata == true) await _carica();
  }

  Future<void> _importaDaQr() async {
    final testo = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerQrScreen()),
    );
    if (testo == null) return;

    final importata = decodificaScheda(testo);
    if (importata == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR non valido: non sembra una scheda Gymapp')),
        );
      }
      return;
    }

    final nuovaSchedaId = await DatabaseHelper.instance.insertScheda(
      Scheda(nome: importata.nome, dataCreazione: DateTime.now().toIso8601String()),
    );
    for (final e in importata.esercizi) {
      await DatabaseHelper.instance.insertEsercizio(
        Esercizio(
          schedaId: nuovaSchedaId,
          nome: e.nome,
          ordine: e.ordine,
          serieTotali: e.serieTotali,
          repTarget: e.repTarget,
          riposoSecondi: e.riposoSecondi,
          categoria: e.categoria,
          note: e.note,
          aTempo: e.aTempo,
        ),
      );
    }
    await _carica();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scheda "${importata.nome}" importata')),
      );
    }
  }

  Future<void> _scartaPausa() async {
    final conferma = await mostraDialogoAzioni<bool>(
      context,
      titolo: 'Interrompere l\'allenamento in pausa?',
      messaggio: 'Non potrai più riprenderlo. Le serie già registrate restano nello storico.',
      chiudibile: true,
      azioni: const [
        AzioneDialogo('Annulla', Icons.arrow_back, false, stile: StileAzione.primaria),
        AzioneDialogo('Interrompi', Icons.stop_circle_outlined, true, stile: StileAzione.pericolo),
      ],
    );
    if (conferma != true) return;
    GestoreSessione.inPausa = null;
    GestoreSessione.inizioAllenamento = null;
    if (mounted) setState(() {});
  }

  Widget _bannerPausa() {
    final sessione = GestoreSessione.inPausa!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accento.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accento, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pause_circle_outline, color: AppColors.accento),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Allenamento in pausa',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Annulla',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _scartaPausa,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 2),
            child: Text(
              sessione.nomeScheda,
              style: TextStyle(color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _riprendiAllenamento,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Riprendi allenamento'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SCHEDE', style: GoogleFonts.oswald(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: 1)),
                IconButton(
                  onPressed: _importaDaQr,
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Importa scheda da QR',
                ),
              ],
            ),
            Text('Le tue schede di allenamento', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            if (GestoreSessione.inPausa != null) _bannerPausa(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _schede.isEmpty
                      ? Center(
                          child: Text(
                            'Nessuna scheda ancora.\nCreane una qui sotto o importane una da QR.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _schede.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final s = _schede[index];
                            final n = _conteggioEsercizi[s.id] ?? 0;
                            return _CardScheda(
                              nome: s.nome,
                              numeroEsercizi: n,
                              onInizia: () => _iniziaAllenamento(s),
                              onApri: () => _apriDettaglio(s),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _nuovaScheda,
              icon: const Icon(Icons.add),
              label: const Text('Nuova scheda'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _creaConAi,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Crea scheda con AI'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: const StadiumBorder(),
                foregroundColor: AppColors.accento,
                side: BorderSide(color: AppColors.accento.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card compatta: tasto play a sinistra, nome e numero di esercizi accanto.
/// Il tocco sulla card apre il dettaglio della scheda.
class _CardScheda extends StatelessWidget {
  final String nome;
  final int numeroEsercizi;
  final VoidCallback onInizia;
  final VoidCallback onApri;

  const _CardScheda({
    required this.nome,
    required this.numeroEsercizi,
    required this.onInizia,
    required this.onApri,
  });

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: coloreSuperficie(context),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        onTap: onApri,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: scuro ? Colors.white.withOpacity(0.06) : Colors.transparent),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onInizia,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 32),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w700, height: 1.15),
                    ),
                    Text(
                      numeroEsercizi == 1 ? '1 esercizio' : '$numeroEsercizi esercizi',
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

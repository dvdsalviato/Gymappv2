import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crea_scheda_ai_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../models/scheda.dart';
import '../services/condivisione_scheda.dart';
import '../state/sessione_allenamento.dart';
import '../theme/app_theme.dart';
import 'scanner_qr_screen.dart';
import 'scheda_editor_screen.dart';
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

  Future<void> _apriEditor(Scheda scheda) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SchedaEditorScreen(scheda: scheda)),
    );
    _carica();
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
    // Un allenamento nuovo sovrascrive un'eventuale pausa precedente.
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
                onPressed: () => setState(() => GestoreSessione.inPausa = null),
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
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final s = _schede[index];
                            final n = _conteggioEsercizi[s.id] ?? 0;
                            return _CardScheda(
                              nome: s.nome,
                              numeroEsercizi: n,
                              onInizia: () => _iniziaAllenamento(s),
                              onModifica: () => _apriEditor(s),
                              onElimina: () => _eliminaScheda(s),
                              onCondividi: () => _condividiScheda(s),
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

class _CardScheda extends StatelessWidget {
  final String nome;
  final int numeroEsercizi;
  final VoidCallback onInizia;
  final VoidCallback onModifica;
  final VoidCallback onElimina;
  final VoidCallback onCondividi;

  const _CardScheda({
    required this.nome,
    required this.numeroEsercizi,
    required this.onInizia,
    required this.onModifica,
    required this.onElimina,
    required this.onCondividi,
  });

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: coloreSuperficie(context),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: scuro ? Colors.white.withOpacity(0.06) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style: GoogleFonts.oswald(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1),
                ),
              ),
              IconButton(
                onPressed: onCondividi,
                icon: const Icon(Icons.qr_code, color: Colors.grey),
                tooltip: 'Condividi come QR',
              ),
              IconButton(
                onPressed: onElimina,
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
              ),
            ],
          ),
          Text(
            '$numeroEsercizi esercizi',
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onInizia,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Inizia'),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: onModifica,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: coloreChip(context), shape: BoxShape.circle),
                  child: Icon(Icons.edit, color: scuro ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

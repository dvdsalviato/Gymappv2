import 'package:flutter/material.dart';
import '../data/csv_allenamenti.dart';
import '../db/database_helper.dart';
import '../screens/main_screen.dart';
import '../services/backup_file.dart';
import '../theme/app_theme.dart';

/// Backup su file e importazione/esportazione dello storico (CSV).
class SezioneDatiBackup extends StatefulWidget {
  const SezioneDatiBackup({super.key});

  @override
  State<SezioneDatiBackup> createState() => _SezioneDatiBackupState();
}

class _SezioneDatiBackupState extends State<SezioneDatiBackup> {
  bool _occupato = false;

  void _messaggio(String testo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  Future<void> _esegui(Future<void> Function() azione) async {
    if (_occupato) return;
    setState(() => _occupato = true);
    try {
      await azione();
    } on FormatException catch (e) {
      _messaggio(e.message);
    } catch (e) {
      _messaggio('Operazione non riuscita: $e');
    } finally {
      if (mounted) setState(() => _occupato = false);
    }
  }

  Future<bool> _conferma(String titolo, String testo, String azione) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: Text(azione),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _avviso(String titolo, String testo) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _ripristinaBackup() async {
    final ok = await _conferma(
      'Ripristinare da file?',
      'Schede, storico, peso e profilo di QUESTO telefono verranno SOSTITUITI con quelli del file di backup. '
          'Se vuoi tenere i dati attuali, prima esporta un backup.',
      'Scegli file',
    );
    if (!ok) return;
    final testo = await ServizioFile.scegliFileTesto();
    if (testo == null) return;
    await ServizioFile.ripristinaDaTesto(testo);
    if (!mounted) return;
    await _avviso('Ripristino completato', 'I dati del file sono stati caricati.');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (r) => false,
    );
  }

  String _data(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _importaCsv() async {
    final testo = await ServizioFile.scegliFileTesto();
    if (testo == null) return;
    final lettura = interpretaCsv(testo);
    if (lettura.righe.isEmpty) {
      throw const FormatException('Nel file non ho trovato nessuna serie valida da importare.');
    }
    final righe = lettura.righe;
    final giorni = righe.map((r) => '${r.data.year}-${r.data.month}-${r.data.day}').toSet().length;
    final esercizi = righe.map((r) => r.esercizio.toLowerCase()).toSet().length;
    final allenamenti = righe.map((r) => r.allenamento.isEmpty ? 'Importato' : r.allenamento).toSet().length;
    var primo = righe.first.data;
    var ultimo = righe.first.data;
    for (final r in righe) {
      if (r.data.isBefore(primo)) primo = r.data;
      if (r.data.isAfter(ultimo)) ultimo = r.data;
    }
    final note = StringBuffer();
    if (lettura.riscaldamento > 0) note.write('\n${lettura.riscaldamento} serie di riscaldamento verranno ignorate.');
    if (lettura.scartate > 0) note.write('\n${lettura.scartate} righe non utilizzabili verranno ignorate.');
    if (lettura.inLibbre) note.write('\nI pesi erano in libbre: li ho convertiti in kg.');

    final ok = await _conferma(
      'Importare lo storico?',
      'Ho trovato ${righe.length} serie in $giorni giorni di allenamento, dal ${_data(primo)} al ${_data(ultimo)}: '
          '$esercizi esercizi in $allenamenti schede.$note\n\n'
          'Le schede e gli esercizi che mancano verranno creati. Quello che c\'è già non viene toccato né duplicato.',
      'Importa',
    );
    if (!ok) return;
    final r = await DatabaseHelper.instance.importaAllenamenti(righe);
    if (!mounted) return;
    final saltate = r.doppioni > 0 ? '\n${r.doppioni} serie c\'erano già e sono state saltate.' : '';
    await _avviso(
      'Importazione completata',
      '${r.serieImportate} serie importate (${r.schedeNuove} schede e ${r.eserciziNuovi} esercizi nuovi).'
      '$saltate\n\nTroverai tutto nello Storico; le medaglie si aggiornano quando apri la Home.',
    );
  }

  Widget _pulsante(IconData icona, String testo, VoidCallback azione) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _occupato ? null : azione,
          icon: Icon(icona),
          label: Text(testo),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: const StadiumBorder(),
            alignment: Alignment.centerLeft,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('I TUOI DATI', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.3, fontSize: 13)),
              ),
              if (_occupato) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Sono tuoi: salvali dove vuoi, oppure portali da un\'altra app.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          const SizedBox(height: 14),
          _pulsante(Icons.upload_file_outlined, 'Esporta backup completo (file)', () => _esegui(ServizioFile.condividiBackup)),
          _pulsante(Icons.restore_outlined, 'Ripristina da file di backup', () => _esegui(_ripristinaBackup)),
          _pulsante(Icons.table_chart_outlined, 'Esporta storico in CSV', () => _esegui(ServizioFile.condividiCsv)),
          _pulsante(Icons.download_outlined, 'Importa storico da CSV (Strong, Hevy…)', () => _esegui(_importaCsv)),
        ],
      ),
    );
  }
}

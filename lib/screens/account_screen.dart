import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../amici/account_servizio.dart';
import '../amici/backup_servizio.dart';
import '../amici/firebase_config.dart';
import '../amici/firestore_rest.dart';
import '../amici/sync_servizio.dart';
import '../amici/pulsante_google_stub.dart' if (dart.library.js_interop) '../amici/pulsante_google_web.dart';
import '../theme/app_theme.dart';

/// Account Google e backup dei dati.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountServizio _account = AccountServizio.istanza;
  final BackupServizio _backup = BackupServizio.istanza;

  StatoAccount _stato = const StatoAccount(false, '');
  InfoBackup? _remoto;
  int _ultimoLocale = 0;
  bool _auto = true;
  bool _caricamento = true;
  bool _occupato = false;
  String? _avvisoRete;
  StreamSubscription<Object>? _esitiWeb;
  bool _webPronto = false;

  @override
  void initState() {
    super.initState();
    _carica();
    if (kIsWeb) _preparaWeb();
  }

  Future<void> _preparaWeb() async {
    _esitiWeb = _account.esitiWeb.listen((esito) async {
      if (esito is AmiciErrore) {
        _avviso(esito.messaggio);
        return;
      }
      await _carica();
      _avviso(esito == true ? 'Account già usato: ho recuperato il tuo profilo.' : 'Account Google collegato.');
      // Primo accesso da qui: si allinea subito con gli altri dispositivi.
      await SyncServizio.istanza.sincronizza(interattivo: true);
      if (mounted) await _carica();
    });
    try {
      await _account.preparaWeb();
      if (mounted) setState(() => _webPronto = true);
    } catch (e) {
      _avviso('Accesso con Google non disponibile: $e');
    }
  }

  @override
  void dispose() {
    _esitiWeb?.cancel();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() => _caricamento = true);
    final stato = await _account.stato();
    final prefs = await SharedPreferences.getInstance();
    InfoBackup? remoto;
    String? avviso;
    if (stato.collegato && firebaseConfigurato) {
      try {
        remoto = await _backup.infoRemoto();
      } on AmiciErrore catch (e) {
        avviso = e.messaggio;
      }
    }
    if (!mounted) return;
    setState(() {
      _stato = stato;
      _remoto = remoto;
      _avvisoRete = avviso;
      _auto = prefs.getBool(BackupServizio.chiaveAuto) ?? true;
      _ultimoLocale = prefs.getInt(BackupServizio.chiaveUltimo) ?? 0;
      _caricamento = false;
    });
  }

  void _avviso(String testo) {
    if (!mounted) return;
    if (testo.length > 90) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Attenzione'),
          content: SingleChildScrollView(child: SelectableText(testo)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
  }

  String _data(DateTime d) {
    String due(int n) => n.toString().padLeft(2, '0');
    return '${due(d.day)}/${due(d.month)}/${d.year} ${due(d.hour)}:${due(d.minute)}';
  }

  Future<void> _esegui(Future<void> Function() azione) async {
    setState(() => _occupato = true);
    try {
      await azione();
    } on AmiciErrore catch (e) {
      _avviso(e.messaggio);
    } catch (e) {
      _avviso('Errore: $e');
    }
    if (mounted) setState(() => _occupato = false);
  }

  Future<void> _accedi() async {
    await _esegui(() async {
      final ripristinato = await _account.accedi();
      await _carica();
      if (ripristinato) {
        _avviso('Account già usato: ho recuperato il tuo profilo.');
      } else {
        _avviso('Account Google collegato.');
      }
      await SyncServizio.istanza.sincronizza(interattivo: true);
      if (mounted) await _carica();
    });
  }

  Future<void> _esci() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uscire dall\'account?'),
        content: const Text(
          'I dati su questo telefono restano. Potrai riaccedere con lo stesso account Google per ritrovare il backup.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Esci'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    await _esegui(() async {
      await _account.esci();
      await _carica();
    });
  }

  Future<void> _faiBackup() async {
    await _esegui(() async {
      final info = await _backup.esegui();
      await _carica();
      _avviso('Backup completato: ${info.schede} schede, ${info.serie} serie.');
    });
  }

  Future<void> _ripristina() async {
    final r = _remoto;
    if (r == null) {
      _avviso('Nel cloud non c\'è ancora nessun backup.');
      return;
    }
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristinare il backup?'),
        content: Text(
          'Schede, storico, peso e profilo di QUESTO telefono verranno SOSTITUITI con quelli del backup del ${_data(r.quando)} '
          '(${r.schede} schede, ${r.serie} serie, ${r.pesi} pesi).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Ripristina'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    await _esegui(() async {
      await _backup.ripristina();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ripristino completato.')));
      // Si torna alla Home ricostruita con i dati appena scaricati.
      Navigator.of(context).popUntil((r) => r.isFirst);
      SyncServizio.istanza.generazione.value++;
    });
  }

  // ------------------------------------------------------------------- UI

  Widget _blocco({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: pannello(context),
        child: child,
      );

  Widget _istruzioni(String titolo, String testo) {
    return _blocco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.settings_suggest_outlined, color: AppColors.accento, size: 34),
          const SizedBox(height: 10),
          Text(titolo, style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(testo, style: TextStyle(color: Colors.grey.shade400, height: 1.35)),
        ],
      ),
    );
  }

  Widget _cardAccount() {
    if (!_stato.collegato) {
      return _blocco(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accedi con Google', style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Così ritrovi schede e storico su tutti i tuoi dispositivi (telefono, computer, iPad) e non li perdi se reinstalli l\'app.',
              style: TextStyle(color: Colors.grey.shade400, height: 1.3),
            ),
            const SizedBox(height: 8),
            Text(
              'Se questo account Google è già stato usato su un altro telefono, il profilo di questo telefono verrà sostituito da quello dell\'account.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 14),
            if (kIsWeb)
              _webPronto
                  ? pulsanteGoogleWeb()
                  : const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            else
              FilledButton.icon(
                onPressed: _occupato ? null : _accedi,
                icon: const Icon(Icons.login),
                label: const Text('Accedi con Google'),
              ),
          ],
        ),
      );
    }
    return _blocco(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.accento, shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, color: Colors.black),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Account Google collegato', style: TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  _stato.email.isEmpty ? 'Accesso effettuato' : _stato.email,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(onPressed: _occupato ? null : _esci, child: const Text('Esci')),
        ],
      ),
    );
  }

  Widget _cardBackup() {
    final r = _remoto;
    return _blocco(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Backup nel cloud', style: GoogleFonts.oswald(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_avvisoRete != null)
            Text(_avvisoRete!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 13))
          else if (r == null)
            Text('Nel cloud non c\'è ancora nessun backup.', style: TextStyle(color: Colors.grey.shade500))
          else
            Text(
              'Ultimo backup: ${_data(r.quando)}\n${r.schede} schede · ${r.serie} serie · ${r.pesi} pesi',
              style: TextStyle(color: Colors.grey.shade400, height: 1.35),
            ),
          if (_ultimoLocale > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Fatto da questo telefono: ${_data(DateTime.fromMillisecondsSinceEpoch(_ultimoLocale))}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _occupato ? null : _faiBackup,
            icon: _occupato
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_occupato ? 'Un attimo...' : 'Esegui backup ora'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: (_occupato || r == null) ? null : _ripristina,
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('Ripristina dal backup'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _auto,
            title: const Text('Sincronizzazione automatica'),
            subtitle: Text(
              'Stessi dati su telefono, computer e tablet collegati a questo account Google.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            onChanged: (v) async {
              setState(() => _auto = v);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(BackupServizio.chiaveAuto, v);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget corpo;
    if (!firebaseConfigurato) {
      corpo = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _istruzioni(
            'Servizio online non configurato',
            'Scrivi chiave API e ID del progetto Firebase in lib/amici/firebase_config.dart e ricompila l\'app.',
          ),
        ],
      );
    } else if (!googleConfigurato) {
      corpo = ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _istruzioni(
            'Manca l\'ID client Google',
            'Scrivi il "Web client ID" in lib/amici/firebase_config.dart (googleWebClientId) e ricompila l\'app.',
          ),
        ],
      );
    } else if (_caricamento) {
      corpo = const Center(child: CircularProgressIndicator());
    } else {
      corpo = RefreshIndicator(
        onRefresh: _carica,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _cardAccount(),
            if (_stato.collegato) ...[
              const SizedBox(height: 14),
              _cardBackup(),
            ],
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Account e backup')),
      body: corpo,
    );
  }
}

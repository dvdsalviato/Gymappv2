import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/catalogo_esercizi.dart';
import '../data/macchinari.dart';
import '../data/classificatore.dart';
import '../data/progressione.dart' show riposoConsigliato;
import '../db/database_helper.dart';
import '../models/esercizio.dart';
import '../theme/app_theme.dart';
import '../data/immagini_esercizi.dart';
import '../widgets/animazione_esercizio.dart';
import '../widgets/selettore_catalogo.dart';

class EditEsercizioScreen extends StatefulWidget {
  final int schedaId;
  final Esercizio? esercizio;
  final int ordineSuggerito;

  const EditEsercizioScreen({
    super.key,
    required this.schedaId,
    this.esercizio,
    required this.ordineSuggerito,
  });

  @override
  State<EditEsercizioScreen> createState() => _EditEsercizioScreenState();
}

class _EditEsercizioScreenState extends State<EditEsercizioScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomeCtrl;
  late TextEditingController _serieCtrl;
  late TextEditingController _repCtrl;
  late TextEditingController _riposoCtrl;
  late TextEditingController _noteCtrl;
  late String _categoria;
  // Vero se la categoria l'ha scelta la persona: allora non la cambio più da solo.
  late bool _categoriaManuale;
  // Ultimo recupero proposto da solo: finché non lo cambi tu, si aggiorna col nome.
  String _riposoAuto = '';
  late bool _aTempo;
  late TextEditingController _minCtrl;
  late TextEditingController _secCtrl;
  // Marchio del macchinario (null = nessuno). Fa parte dell'identità
  // dell'esercizio: macchine diverse hanno storici separati.
  String? _macchinario;
  String? _macchinarioOriginale;
  List<String> _recenti = [];
  static const _chiaveRecenti = 'macchinari_recenti';

  @override
  void initState() {
    super.initState();
    final e = widget.esercizio;
    final separato = separaMacchinario(e?.nome ?? '');
    _macchinario = separato.macchinario;
    _macchinarioOriginale = separato.macchinario;
    _nomeCtrl = TextEditingController(text: separato.base);
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _recenti = prefs.getStringList(_chiaveRecenti) ?? []);
    });
    _serieCtrl = TextEditingController(text: e != null ? e.serieTotali.toString() : '');
    _repCtrl = TextEditingController(text: e != null ? e.repTarget.toString() : '');
    _riposoCtrl = TextEditingController(text: e != null ? e.riposoSecondi.toString() : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _categoria = e?.categoria ?? 'Altro';
    _categoriaManuale = e != null && e.categoria != 'Altro';
    if (e != null && !_categoriaManuale) {
      _categoria = classificaEsercizio(e.nome) ?? 'Altro';
    }
    _aTempo = e?.aTempo ?? false;
    final durata = (e != null && e.aTempo) ? e.repTarget : 60;
    _minCtrl = TextEditingController(text: (durata ~/ 60).toString());
    _secCtrl = TextEditingController(text: (durata % 60).toString());
    _nomeCtrl.addListener(() {
      _suggerisciCategoria();
      _suggerisciRiposo();
    });
  }

  /// Per un esercizio nuovo propone il recupero in base al tipo di esercizio.
  void _suggerisciRiposo() {
    if (widget.esercizio != null) return;
    if (_nomeCtrl.text.trim().length < 3) return;
    if (_riposoCtrl.text.isNotEmpty && _riposoCtrl.text != _riposoAuto) return;
    final r = riposoConsigliato(_nomeCtrl.text).toString();
    _riposoAuto = r;
    _riposoCtrl.text = r;
  }

  /// Mentre scrivi il nome, riconosce da solo la categoria (se non l'hai
  /// già scelta tu).
  void _suggerisciCategoria() {
    if (_categoriaManuale) return;
    final c = classificaEsercizio(_nomeCtrl.text) ?? 'Altro';
    if (c != _categoria && mounted) setState(() => _categoria = c);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _serieCtrl.dispose();
    _repCtrl.dispose();
    _riposoCtrl.dispose();
    _noteCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (!_formKey.currentState!.validate()) return;

    final testoNote = _noteCtrl.text.trim();

    var target = 0;
    if (_aTempo) {
      final minuti = int.tryParse(_minCtrl.text.trim()) ?? 0;
      final secondi = int.tryParse(_secCtrl.text.trim()) ?? 0;
      target = minuti * 60 + secondi;
      if (target < 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La durata deve essere di almeno 5 secondi')),
        );
        return;
      }
    } else {
      target = int.parse(_repCtrl.text);
    }

    final nuovo = Esercizio(
      id: widget.esercizio?.id,
      schedaId: widget.schedaId,
      nome: componiNome(_nomeCtrl.text, _macchinario),
      ordine: widget.esercizio?.ordine ?? widget.ordineSuggerito,
      serieTotali: int.parse(_serieCtrl.text),
      repTarget: target,
      riposoSecondi: int.parse(_riposoCtrl.text),
      note: testoNote.isEmpty ? null : testoNote,
      categoria: _categoria,
      aTempo: _aTempo,
    );

    var altreSchede = 0;
    if (widget.esercizio == null) {
      await DatabaseHelper.instance.insertEsercizio(nuovo);
    } else if (_macchinario != _macchinarioOriginale && await _macchinaDiversa()) {
      // Le serie fatte finora erano su un'altra macchina: storico nuovo.
      await DatabaseHelper.instance.separaEsercizio(nuovo);
    } else {
      altreSchede = await DatabaseHelper.instance.updateEsercizio(nuovo);
    }
    await _ricordaMacchinario();

    if (!mounted) return;
    if (altreSchede > 0) {
      // Lo stesso esercizio è in altre schede: nome e gruppo valgono ovunque.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            altreSchede == 1
                ? 'Aggiornato anche nell\'altra scheda che lo usa: lo storico resta unito'
                : 'Aggiornato anche nelle altre $altreSchede schede che lo usano: lo storico resta unito',
          ),
        ),
      );
    }
    Navigator.pop(context, true);
  }

  /// Il macchinario è cambiato su un esercizio con storico: le serie già
  /// fatte erano su questa macchina (lo storico la segue) o su un'altra?
  /// Vero = macchina diversa, si riparte con uno storico nuovo.
  Future<bool> _macchinaDiversa() async {
    final id = widget.esercizio?.id;
    if (id == null) return false;
    final serie = await DatabaseHelper.instance.contaSerieEsercizio(id);
    if (serie == 0 || !mounted) return false;
    final nuovo = _macchinario ?? 'una macchina senza marchio indicato';
    final scelta = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Hai cambiato macchinario'),
        content: Text(
          'Le $serie serie già registrate erano fatte su $nuovo?\n\n'
          'Se sì, lo storico resta con questo esercizio. Se era un\'altra macchina, '
          'ripartirai con uno storico nuovo e quello vecchio resterà con il nome di prima.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Era un\'altra')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Sì, questa'),
          ),
        ],
      ),
    );
    return scelta == true;
  }

  Future<void> _ricordaMacchinario() async {
    final m = _macchinario;
    if (m == null) return;
    final prefs = await SharedPreferences.getInstance();
    final lista = [m, ...(prefs.getStringList(_chiaveRecenti) ?? []).where((x) => x != m)].take(4).toList();
    await prefs.setStringList(_chiaveRecenti, lista);
  }

  Future<void> _altroMacchinario() async {
    final ctrl = TextEditingController(text: _macchinario ?? '');
    final scelto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marchio del macchinario'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'es. Technogym'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
    if (scelto == null) return;
    setState(() => _macchinario = scelto.isEmpty ? null : scelto.replaceAll(separatoreMacchinario, ' '));
  }

  Widget _chipMacchinario(String etichetta, bool selezionato, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selezionato ? AppColors.accento.withValues(alpha: 0.15) : coloreChip(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selezionato ? AppColors.accento : Colors.transparent, width: 2),
        ),
        child: Text(etichetta),
      ),
    );
  }

  Widget _sezioneMacchinario() {
    final marche = <String>[
      ..._recenti,
      ...marcheMacchinari.where((m) => !_recenti.contains(m)),
    ];
    final personalizzato = _macchinario != null && !marche.contains(_macchinario);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Macchinario', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          'Per macchine e cavi: marchi diversi hanno resistenze diverse, quindi ogni marchio ha il suo storico.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chipMacchinario('Nessuno', _macchinario == null, () => setState(() => _macchinario = null)),
            for (final m in marche)
              _chipMacchinario(m, _macchinario == m, () => setState(() => _macchinario = m)),
            _chipMacchinario(personalizzato ? _macchinario! : 'Altro…', personalizzato, _altroMacchinario),
          ],
        ),
      ],
    );
  }

  String? _validaIntero(String? valore, {int min = 1}) {
    if (valore == null || valore.trim().isEmpty) return 'Obbligatorio';
    final n = int.tryParse(valore);
    if (n == null || n < min) return 'Numero non valido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esercizio == null ? 'Nuovo esercizio' : 'Modifica esercizio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nomeCtrl,
                decoration: InputDecoration(
                  labelText: 'Nome esercizio',
                  hintText: 'es. Panca piana',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.list_alt),
                    tooltip: 'Scegli dal catalogo',
                    onPressed: () async {
                      final scelto = await mostraCatalogoEsercizi(context);
                      if (scelto != null) {
                        _categoriaManuale = false;
                        _nomeCtrl.text = scelto.nome;
                        setState(() {
                          _categoria = scelto.categoria;
                          _aTempo = scelto.durataSecondi > 0;
                          if (_aTempo) {
                            _minCtrl.text = (scelto.durataSecondi ~/ 60).toString();
                            _secCtrl.text = (scelto.durataSecondi % 60).toString();
                          }
                        });
                      }
                    },
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 14),
              Text(
                (!_categoriaManuale && _categoria != 'Altro')
                    ? 'Categoria muscolare (riconosciuta in automatico)'
                    : 'Categoria muscolare',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categorieEsercizio.map((c) {
                  final selezionata = c == _categoria;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _categoria = c;
                      _categoriaManuale = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selezionata ? AppColors.accento.withValues(alpha: 0.15) : coloreChip(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selezionata ? AppColors.accento : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(c),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _sezioneMacchinario(),
              const SizedBox(height: 14),
              // Immagine dell'esecuzione: se quella trovata è sbagliata la cambi qui.
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nomeCtrl,
                builder: (context, valore, _) {
                  final nome = valore.text.trim();
                  final trovata = nome.isNotEmpty && haImmagine(nome);
                  return Row(
                    children: [
                      MiniaturaEsercizio(nomeEsercizio: nome.isEmpty ? '-' : nome, dimensione: 56, aTempo: _aTempo),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trovata ? 'Immagine dell\'esecuzione' : 'Nessuna immagine trovata',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: nome.isEmpty
                            ? null
                            : () async {
                                if (await cambiaImmagineEsercizio(context, nome) && mounted) setState(() {});
                              },
                        child: Text(trovata ? 'Cambia' : 'Scegli'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _serieCtrl,
                decoration: const InputDecoration(
                  labelText: 'Numero serie',
                  hintText: 'es. 3',
                ),
                keyboardType: TextInputType.number,
                validator: _validaIntero,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Ripetizioni'), icon: Icon(Icons.repeat)),
                    ButtonSegment(value: true, label: Text('A tempo'), icon: Icon(Icons.timer_outlined)),
                  ],
                  selected: {_aTempo},
                  onSelectionChanged: (s) => setState(() => _aTempo = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.accento,
                    selectedForegroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (_aTempo)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _minCtrl,
                        decoration: const InputDecoration(labelText: 'Minuti', hintText: 'es. 5'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _secCtrl,
                        decoration: const InputDecoration(labelText: 'Secondi', hintText: 'es. 45'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                )
              else
                TextFormField(
                  controller: _repCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ripetizioni target',
                    hintText: 'es. 10',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _validaIntero,
                ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _riposoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Riposo (secondi)',
                  hintText: 'es. 90',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _validaIntero(v, min: 0),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (facoltativo)',
                  hintText: 'es. gomiti stretti, non bloccare le ginocchia...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _salva,
                child: const Text('Salva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;
import 'classificatore.dart';

String formatKg(double v) {
  final testo = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  return testo.replaceAll('.', ',');
}

class Suggerimento {
  final double carico;
  final String testo;
  final bool aumento;
  const Suggerimento(this.carico, this.testo, this.aumento);
}

enum _TipoCarico { compostoGambe, composto, isolamento }

_TipoCarico _tipoCarico(String nome) {
  if (nomeContiene(nome, [
    'squat', 'leg press', 'pressa', 'stacco', 'stacchi', 'deadlift', 'dead lift', 'hip thrust', 'rdl',
    'romanian', 'rack pull', 'hack', 'good morning', 'affondi', 'lunge', 'step up',
  ])) {
    return _TipoCarico.compostoGambe;
  }
  if (nomeContiene(nome, [
    'panca', 'bench', 'military', 'overhead press', 'lento avanti', 'rematore', 'row', 'trazioni',
    'pull up', 'lat machine', 'pulldown', 'chest press', 'shoulder press', 'dip', 'dips', 'push press',
  ])) {
    return _TipoCarico.composto;
  }
  return _TipoCarico.isolamento;
}

double _arrotonda(double v, double passo) => (v / passo).round() * passo;

/// Quanto salire di carico: si usa una percentuale (circa 5% per i
/// fondamentali delle gambe, 2,5% per gli altri multiarticolari, 2,5% per
/// gli isolamenti) arrotondata ai dischi che si trovano in palestra, con un
/// minimo di 2,5 kg per i fondamentali e 1 kg per gli isolamenti.
double incrementoCarico(double carico, String nome) {
  final tipo = _tipoCarico(nome);
  if (tipo == _TipoCarico.compostoGambe) return math.max(2.5, _arrotonda(carico * 0.05, 2.5));
  if (tipo == _TipoCarico.composto) return math.max(2.5, _arrotonda(carico * 0.025, 2.5));
  return math.max(1.0, _arrotonda(carico * 0.025, 0.5));
}

/// Carico ridotto di circa il 10%, sempre un valore realmente caricabile.
double _caricoRidotto(double carico, String nome) {
  final passo = _tipoCarico(nome) == _TipoCarico.isolamento ? 0.5 : 2.5;
  final ridotto = _arrotonda(carico * 0.9, passo);
  return (ridotto > 0 && ridotto < carico) ? ridotto : carico;
}

/// Propone il carico per la serie, con la regola della doppia progressione:
///  - si sale solo quando le ripetizioni previste sono state raggiunte (e, se
///    [consentiAumento] è vero, in tutte le serie dell'ultima volta);
///  - se le ripetizioni sono poche rispetto all'obiettivo si resta sullo
///    stesso carico finché non si arriva al target;
///  - se sono meno della metà del target il carico è troppo alto: si scende
///    di circa il 10%.
/// Durante lo stesso allenamento non si sale mai di carico: si sale la volta
/// dopo.
Suggerimento? suggerisciCarico(
  double carico,
  int rep,
  int repTarget, {
  String nome = '',
  bool consentiAumento = true,
}) {
  if (carico <= 0 || rep <= 0 || repTarget <= 0) return null;
  final mantieni = Suggerimento(carico, 'Stesso carico: sali quando arrivi a $repTarget reps in tutte le serie', false);
  if (rep >= repTarget) {
    if (!consentiAumento) return mantieni;
    final inc = incrementoCarico(carico, nome);
    return Suggerimento(
      carico + inc,
      'Hai raggiunto le $repTarget reps in tutte le serie: sali di ${formatKg(inc)} kg',
      true,
    );
  }
  if (rep >= (repTarget / 2).ceil()) return mantieni;
  final ridotto = _caricoRidotto(carico, nome);
  if (ridotto < carico) {
    return Suggerimento(ridotto, 'Solo $rep reps su $repTarget: il carico è alto, prova con ${formatKg(ridotto)} kg', false);
  }
  return mantieni;
}

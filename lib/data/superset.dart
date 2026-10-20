import '../state/sessione_allenamento.dart';

/// Logica dei superset sulla coda dell'allenamento. È tenuta qui, fuori dalla
/// schermata, per poterla provare con test automatici.

/// Mette uno dopo l'altro gli esercizi dello stesso superset, nel punto in cui compare il primo.
List<VoceCoda> raggruppaSuperset(List<VoceCoda> coda) {
  final risultato = <VoceCoda>[];
  final inseriti = <VoceCoda>{};
  for (final v in coda) {
    if (inseriti.contains(v)) continue;
    risultato.add(v);
    inseriti.add(v);
    final id = v.esercizio.supersetId;
    if (id == 0) continue;
    for (final altro in coda) {
      if (!inseriti.contains(altro) && altro.esercizio.supersetId == id) {
        risultato.add(altro);
        inseriti.add(altro);
      }
    }
  }
  return risultato;
}

/// Se l'esercizio in testa alla coda è in un superset e ci sono compagni ancora
/// da fare, restituisce quello che tocca dopo questa serie. Prima si completa
/// il giro (chi ha ancora la serie di questo giro da fare), poi si riparte dal
/// primo in ordine di scheda.
VoceCoda? compagnoSuperset(List<VoceCoda> coda) {
  final corrente = coda.first;
  final id = corrente.esercizio.supersetId;
  if (id == 0) return null;
  final altri = coda.skip(1).where((v) => v.esercizio.supersetId == id).toList();
  if (altri.isEmpty) return null;
  final inAttesa = altri.where((v) => v.numeroSerie <= corrente.numeroSerie).toList();
  final candidati = inAttesa.isNotEmpty ? inAttesa : altri;
  candidati.sort((a, b) {
    final c = a.numeroSerie.compareTo(b.numeroSerie);
    return c != 0 ? c : a.esercizio.ordine.compareTo(b.esercizio.ordine);
  });
  return candidati.first;
}

/// Vero se dopo la serie in corso si passa subito a un compagno del superset, senza recupero.
bool transizioneSuperset(List<VoceCoda> coda) {
  final corrente = coda.first;
  final id = corrente.esercizio.supersetId;
  if (id == 0) return false;
  return coda.skip(1).any((v) => v.esercizio.supersetId == id && v.numeroSerie <= corrente.numeroSerie);
}

/// Aggiorna la coda dopo una serie: l'esercizio in testa esce se era l'ultima
/// serie, altrimenti passa alla serie successiva; se c'è un [compagno] del
/// superset questo passa in testa (e l'esercizio appena fatto resta dietro).
void avanzaCoda(List<VoceCoda> coda, VoceCoda? compagno) {
  final corrente = coda.first;
  if (corrente.numeroSerie >= corrente.esercizio.serieTotali) {
    coda.removeAt(0);
  } else {
    corrente.numeroSerie++;
  }
  if (compagno != null) {
    coda.remove(compagno);
    coda.insert(0, compagno);
  }
}

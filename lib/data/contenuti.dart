/// Contenuti fissi della Home: un consiglio e una ricetta diversi ogni giorno.
/// Sono consigli generali, non sostituiscono un professionista.

const List<String> consigliDelGiorno = [
  "Riscaldati sempre: 5-10 minuti di cardio leggero e qualche serie di avvicinamento prima dell'esercizio principale.",
  "Dormi 7-9 ore: il muscolo cresce durante il recupero, non mentre ti alleni.",
  "Aumenta il carico poco alla volta: sali di 2,5 kg quando completi tutte le ripetizioni previste.",
  "Bevi regolarmente durante l'allenamento: anche una lieve disidratazione fa calare le prestazioni.",
  "Cura la tecnica prima del peso: un movimento pulito vale più di un carico alto.",
  "Cerca di inserire una fonte di proteine in ogni pasto principale.",
  "Respira: espira nella fase di sforzo e inspira in quella di ritorno.",
  "Registra i tuoi allenamenti: ciò che si misura, migliora.",
  "Non saltare il defaticamento: qualche minuto di stretching leggero aiuta a rilassarti.",
  "I giorni di riposo fanno parte del programma, non sono tempo perso.",
  "Fai prima gli esercizi multiarticolari (squat, panca, rematore) e dopo quelli di isolamento.",
  "Mantieni la schiena neutra negli esercizi con carico: se si arrotonda, riduci il peso.",
  "Segui la stessa scheda per 6-8 settimane prima di cambiarla: così vedi davvero i progressi.",
  "Una camminata dopo i pasti fa bene a digestione e umore.",
  "Non confrontarti con gli altri: confrontati con te stesso del mese scorso.",
  "Negli esercizi di spinta tieni il polso allineato all'avambraccio per evitare fastidi.",
  "Dopo l'allenamento abbina carboidrati e proteine per favorire il recupero.",
  "Un dolore acuto non è la normale fatica muscolare: fermati e chiedi il parere di un professionista.",
  "Recuperi indicativi: 60-90 secondi per i lavori da massa, 2-3 minuti per i carichi più pesanti.",
  "Fai stretching dinamico prima di allenarti e statico alla fine.",
  "Rallenta la discesa (2-3 secondi): più controllo significa lavoro più utile per il muscolo.",
  "Un buon allenamento è quello che riesci a ripetere con costanza.",
  "Porta sempre borraccia e asciugamano: le piccole abitudini fanno la differenza.",
  "Prepara la borsa la sera prima: toglie una scusa al tuo \"non ho voglia\".",
];

class RicettaFit {
  final String titolo;
  final String tipo;
  final List<String> ingredienti;
  final List<String> preparazione;

  const RicettaFit(this.titolo, this.tipo, this.ingredienti, this.preparazione);
}

const List<RicettaFit> ricetteFit = [
  RicettaFit(
    "Overnight oats proteici",
    "Colazione · 5 min + una notte",
    ["50 g di fiocchi d'avena", "150 ml di latte o bevanda vegetale", "100 g di yogurt greco", "1 cucchiaino di miele", "Frutta fresca a piacere"],
    ["Mescola avena, latte e yogurt in un barattolo.", "Chiudi e lascia in frigo tutta la notte.", "Al mattino aggiungi frutta e miele."],
  ),
  RicettaFit(
    "Frittata di albumi e spinaci",
    "Colazione o cena · 10 min",
    ["4 albumi e 1 uovo intero", "100 g di spinaci", "1 cucchiaino di olio extravergine", "Sale e pepe"],
    ["Scalda l'olio e fai appassire gli spinaci per 2 minuti.", "Versa le uova sbattute con sale e pepe.", "Cuoci a fuoco medio-basso con il coperchio finché è rassodata."],
  ),
  RicettaFit(
    "Insalata di pollo e ceci",
    "Pranzo · 15 min",
    ["150 g di petto di pollo", "100 g di ceci già cotti", "Pomodorini e rucola", "Olio extravergine e succo di limone"],
    ["Cuoci il pollo sulla piastra e taglialo a strisce.", "Unisci ceci, pomodorini e rucola in una ciotola.", "Aggiungi il pollo e condisci con olio e limone."],
  ),
  RicettaFit(
    "Bowl di riso, tonno e avocado",
    "Pranzo · 15 min",
    ["80 g di riso (peso a crudo)", "1 scatoletta di tonno al naturale", "1/2 avocado", "Cetriolo e mais", "Salsa di soia o limone"],
    ["Cuoci il riso e lascialo intiepidire.", "Componi la bowl con riso, tonno, avocado a fette e verdure.", "Condisci con soia o limone."],
  ),
  RicettaFit(
    "Pancake d'avena e banana",
    "Colazione · 10 min",
    ["1 banana matura", "2 uova", "40 g di fiocchi d'avena", "Cannella"],
    ["Schiaccia la banana e frulla o mescola con uova, avena e cannella.", "Cuoci piccole porzioni in padella antiaderente 2 minuti per lato.", "Servi con yogurt o frutta."],
  ),
  RicettaFit(
    "Zuppa di lenticchie e verdure",
    "Cena · 25 min",
    ["150 g di lenticchie già cotte", "1 carota, 1 costa di sedano, 1/2 cipolla", "Brodo vegetale", "1 cucchiaio di olio extravergine"],
    ["Soffriggi le verdure tritate nell'olio per 5 minuti.", "Aggiungi lenticchie e brodo, cuoci 15 minuti.", "Frulla in parte per una consistenza cremosa."],
  ),
  RicettaFit(
    "Salmone al forno con broccoli",
    "Cena · 25 min",
    ["150 g di filetto di salmone", "200 g di broccoli", "1 patata piccola", "Olio, limone, sale e pepe"],
    ["Taglia patata e broccoli e mettili in teglia con un filo d'olio.", "Aggiungi il salmone con limone, sale e pepe.", "Inforna a 200 °C per circa 18-20 minuti."],
  ),
  RicettaFit(
    "Yogurt greco, frutti rossi e noci",
    "Spuntino · 3 min",
    ["170 g di yogurt greco bianco", "Una manciata di frutti rossi", "3-4 noci spezzettate", "Un filo di miele (facoltativo)"],
    ["Versa lo yogurt in una ciotola.", "Aggiungi frutti rossi e noci.", "Completa con un filo di miele."],
  ),
];

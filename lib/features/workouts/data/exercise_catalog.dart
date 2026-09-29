class CatalogExercise {
  final String name;
  final String category;

  const CatalogExercise({required this.name, required this.category});
}

const List<CatalogExercise> defaultExercises = [
  // PETTO
  CatalogExercise(name: 'Panca piana con bilanciere', category: 'Petto'),
  CatalogExercise(name: 'Panca piana con manubri', category: 'Petto'),
  CatalogExercise(name: 'Panca inclinata con bilanciere', category: 'Petto'),
  CatalogExercise(name: 'Panca inclinata con manubri', category: 'Petto'),
  CatalogExercise(name: 'Panca declinata con bilanciere', category: 'Petto'),
  CatalogExercise(name: 'Panca declinata con manubri', category: 'Petto'),
  CatalogExercise(name: 'Chest press', category: 'Petto'),
  CatalogExercise(name: 'Croci panca piana con manubri', category: 'Petto'),
  CatalogExercise(name: 'Croci panca inclinata con manubri', category: 'Petto'),
  CatalogExercise(name: 'Croci ai cavi alti', category: 'Petto'),
  CatalogExercise(name: 'Croci ai cavi bassi', category: 'Petto'),
  CatalogExercise(name: 'Pec deck / Squeeze press', category: 'Petto'),
  CatalogExercise(name: 'Dip alle parallele (focus petto)', category: 'Petto'),
  CatalogExercise(name: 'Push-up / Flessioni', category: 'Petto'),
  CatalogExercise(name: 'Pullover con manubrio', category: 'Petto'),

  // SCHIENA
  CatalogExercise(name: 'Trazioni alla sbarra (prona)', category: 'Schiena'),
  CatalogExercise(name: 'Trazioni alla sbarra (supina / Chin-up)', category: 'Schiena'),
  CatalogExercise(name: 'Lat machine avanti', category: 'Schiena'),
  CatalogExercise(name: 'Lat machine presa inversa', category: 'Schiena'),
  CatalogExercise(name: 'Lat machine presa stretta / neutral', category: 'Schiena'),
  CatalogExercise(name: 'Pulley basso con maniglia V', category: 'Schiena'),
  CatalogExercise(name: 'Pulley basso barra larga', category: 'Schiena'),
  CatalogExercise(name: 'Rematore con bilanciere', category: 'Schiena'),
  CatalogExercise(name: 'Rematore con manubrio', category: 'Schiena'),
  CatalogExercise(name: 'Rematore T-Bar', category: 'Schiena'),
  CatalogExercise(name: 'Seal row', category: 'Schiena'),
  CatalogExercise(name: 'Stacco da terra (Deadlift)', category: 'Schiena'),
  CatalogExercise(name: 'Hyper-extension / Panca ipestensioni', category: 'Schiena'),
  CatalogExercise(name: 'Pulldown a braccia tese ai cavi', category: 'Schiena'),
  CatalogExercise(name: 'Shrug / Scrollate con manubri', category: 'Schiena'),

  // SPALLE
  CatalogExercise(name: 'Military press con bilanciere', category: 'Spalle'),
  CatalogExercise(name: 'Shoulder press con manubri', category: 'Spalle'),
  CatalogExercise(name: 'Arnold press', category: 'Spalle'),
  CatalogExercise(name: 'Press dietro nuca', category: 'Spalle'),
  CatalogExercise(name: 'Push press', category: 'Spalle'),
  CatalogExercise(name: 'Alzate laterali con manubri', category: 'Spalle'),
  CatalogExercise(name: 'Alzate laterali ai cavi', category: 'Spalle'),
  CatalogExercise(name: 'Alzate laterali alla macchina', category: 'Spalle'),
  CatalogExercise(name: 'Alzate frontali con manubri', category: 'Spalle'),
  CatalogExercise(name: 'Alzate frontali con disco/bilanciere', category: 'Spalle'),
  CatalogExercise(name: 'Face pull ai cavi', category: 'Spalle'),
  CatalogExercise(name: 'Alzate posteriori a 90° con manubri', category: 'Spalle'),
  CatalogExercise(name: 'Reverse fly / Rear delt pec deck', category: 'Spalle'),

  // GAMBE
  CatalogExercise(name: 'Squat con bilanciere', category: 'Gambe'),
  CatalogExercise(name: 'Front squat', category: 'Gambe'),
  CatalogExercise(name: 'Goblet squat', category: 'Gambe'),
  CatalogExercise(name: 'Hack squat', category: 'Gambe'),
  CatalogExercise(name: 'Leg press 45°', category: 'Gambe'),
  CatalogExercise(name: 'Leg press orizzontale', category: 'Gambe'),
  CatalogExercise(name: 'Bulgarian split squat', category: 'Gambe'),
  CatalogExercise(name: 'Affondi camminati con manubri', category: 'Gambe'),
  CatalogExercise(name: 'Affondi sul posto', category: 'Gambe'),
  CatalogExercise(name: 'Leg extension', category: 'Gambe'),
  CatalogExercise(name: 'Leg curl da seduto', category: 'Gambe'),
  CatalogExercise(name: 'Leg curl sdraiato', category: 'Gambe'),
  CatalogExercise(name: 'Romanian deadlift (RDL) con bilanciere', category: 'Gambe'),
  CatalogExercise(name: 'Romanian deadlift con manubri', category: 'Gambe'),
  CatalogExercise(name: 'Stacco sumo', category: 'Gambe'),
  CatalogExercise(name: 'Hip thrust con bilanciere', category: 'Gambe'),
  CatalogExercise(name: 'Glute bridge', category: 'Gambe'),
  CatalogExercise(name: 'Abductor machine', category: 'Gambe'),
  CatalogExercise(name: 'Adductor machine', category: 'Gambe'),
  CatalogExercise(name: 'Calf raise in piedi', category: 'Gambe'),
  CatalogExercise(name: 'Calf raise da seduto', category: 'Gambe'),

  // BICIPITI
  CatalogExercise(name: 'Curl con bilanciere sagomato (EZ)', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl con bilanciere dritto', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl alternato con manubri', category: 'Bicipiti'),
  CatalogExercise(name: 'Hammer curl con manubri', category: 'Bicipiti'),
  CatalogExercise(name: 'Hammer curl ai cavi con corda', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl panca Scott (Preacher curl)', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl concentrato', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl su panca inclinata', category: 'Bicipiti'),
  CatalogExercise(name: 'Curl ai cavi bassi', category: 'Bicipiti'),
  CatalogExercise(name: 'Spider curl', category: 'Bicipiti'),

  // TRICIPITI
  CatalogExercise(name: 'Pushdown ai cavi con corda', category: 'Tricipiti'),
  CatalogExercise(name: 'Pushdown ai cavi con barra dritta/V', category: 'Tricipiti'),
  CatalogExercise(name: 'French press con bilanciere EZ', category: 'Tricipiti'),
  CatalogExercise(name: 'French press con manubri su panca', category: 'Tricipiti'),
  CatalogExercise(name: 'Estensioni sopra la testa con manubrio', category: 'Tricipiti'),
  CatalogExercise(name: 'Estensioni sopra la testa ai cavi', category: 'Tricipiti'),
  CatalogExercise(name: 'Dip su panca', category: 'Tricipiti'),
  CatalogExercise(name: 'Dip alle parallele (focus tricipiti)', category: 'Tricipiti'),
  CatalogExercise(name: 'Panca piana presa stretta', category: 'Tricipiti'),
  CatalogExercise(name: 'Kickback con manubrio', category: 'Tricipiti'),

  // CORE
  CatalogExercise(name: 'Crunch a terra', category: 'Core'),
  CatalogExercise(name: 'Crunch inverso', category: 'Core'),
  CatalogExercise(name: 'Crunch ai cavi (Cable crunch)', category: 'Core'),
  CatalogExercise(name: 'Plank addominale', category: 'Core'),
  CatalogExercise(name: 'Side plank', category: 'Core'),
  CatalogExercise(name: 'Leg raise alla sbarra', category: 'Core'),
  CatalogExercise(name: 'Leg raise su panca', category: 'Core'),
  CatalogExercise(name: 'Ab wheel rollout', category: 'Core'),
  CatalogExercise(name: 'Russian twist', category: 'Core'),
  CatalogExercise(name: 'Mountain climber', category: 'Core'),

  // ALTRO
  CatalogExercise(name: 'Farmer walk / Camminata del contadino', category: 'Altro'),
  CatalogExercise(name: 'Kettlebell swing', category: 'Altro'),
  CatalogExercise(name: 'Burpees', category: 'Altro'),
  CatalogExercise(name: 'Corda per saltare', category: 'Altro'),
  CatalogExercise(name: 'Vogatore / Rower', category: 'Altro'),
];

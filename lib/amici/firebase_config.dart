/// Configurazione del servizio "Amici" (Firebase).
///
/// Sostituisci i due valori con quelli del tuo progetto Firebase
/// (Impostazioni progetto > Generali: "ID progetto" e "Chiave API web").
/// Finché restano "INSERISCI_...", la sezione Amici mostra solo le istruzioni
/// e il resto dell'app funziona normalmente.
const String firebaseApiKey = 'AIzaSyDT7NxFieu7pg4QJl6ZKeEpn2Mphu1HXCs';
const String firebaseProjectId = 'gymapp-1810';

/// ID client "Web" per l'accesso con Google (Firebase > Authentication >
/// Metodo di accesso > Google > Configurazione SDK web). Finisce con
/// ".apps.googleusercontent.com".
const String googleWebClientId = '194621746125-eq029e98h0gdtkqo2k9vpignvgbbufs8.apps.googleusercontent.com';

bool get googleConfigurato => firebaseConfigurato && !googleWebClientId.startsWith('INSERISCI');

bool get firebaseConfigurato =>
    !firebaseApiKey.startsWith('INSERISCI') && !firebaseProjectId.startsWith('INSERISCI');

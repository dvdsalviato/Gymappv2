import 'package:flutter/widgets.dart';

/// Navigatore principale dell'app: serve ai servizi in background (per
/// esempio la sincronizzazione) per sapere su che schermata si è e per
/// mostrare un dialogo.
final GlobalKey<NavigatorState> navigatoreApp = GlobalKey<NavigatorState>();

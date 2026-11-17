import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiene lo stato del tema (chiaro/scuro) e lo salva sul telefono,
/// così resta impostato anche riaprendo l'app.
class ThemeController {
  static final ValueNotifier<ThemeMode> modalita = ValueNotifier(ThemeMode.dark);

  /// Colore principale scelto (indice della palette in app_theme.dart).
  static final ValueNotifier<int> colore = ValueNotifier(0);

  static const _chiave = 'tema_scuro';
  static const _chiaveColore = 'colore_app';
  static const _chiavePersonalizzato = 'colore_personalizzato';

  /// Colore scelto con il cerchio dei colori (valore ARGB). Si usa quando
  /// [colore] vale quanto la lunghezza della palette.
  static final ValueNotifier<int> personalizzato = ValueNotifier(0xFFA3E635);

  static Future<void> carica() async {
    final prefs = await SharedPreferences.getInstance();
    final scuro = prefs.getBool(_chiave) ?? true;
    modalita.value = scuro ? ThemeMode.dark : ThemeMode.light;
    personalizzato.value = prefs.getInt(_chiavePersonalizzato) ?? 0xFFA3E635;
    colore.value = prefs.getInt(_chiaveColore) ?? 0;
  }

  /// Usa un colore libero (indice [indicePersonalizzato] nella palette).
  static Future<void> scegliPersonalizzato(int argb, int indicePersonalizzato) async {
    personalizzato.value = argb;
    colore.value = indicePersonalizzato;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chiavePersonalizzato, argb);
    await prefs.setInt(_chiaveColore, indicePersonalizzato);
  }

  static Future<void> cambiaColore(int indice) async {
    colore.value = indice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_chiaveColore, indice);
  }

  static Future<void> cambia(bool scuro) async {
    modalita.value = scuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiave, scuro);
  }
}

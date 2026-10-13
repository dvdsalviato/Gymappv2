import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiene lo stato del tema (chiaro/scuro) e lo salva sul telefono,
/// così resta impostato anche riaprendo l'app.
class ThemeController {
  static final ValueNotifier<ThemeMode> modalita = ValueNotifier(ThemeMode.dark);

  static const _chiave = 'tema_scuro';

  static Future<void> carica() async {
    final prefs = await SharedPreferences.getInstance();
    final scuro = prefs.getBool(_chiave) ?? true;
    modalita.value = scuro ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> cambia(bool scuro) async {
    modalita.value = scuro ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chiave, scuro);
  }
}

import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/sfondo_texturizzato.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.carica();
  runApp(const GymappApp());
}

class GymappApp extends StatelessWidget {
  const GymappApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.modalita,
      builder: (context, modalita, _) {
        return MaterialApp(
          title: 'Gymapp V2',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: modalita,
          builder: (context, child) => SfondoTexturizzato(
            scuro: modalita == ThemeMode.dark,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

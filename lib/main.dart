import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definizione dei colori Cyber / Fluo
    const neonGreen = Color(0xFF00FF66); // Verde Fluo / Lime brillante
    const darkBackground = Color(0xFF121212);
    const cardBackground = Color(0xFF1E1E1E);

    return MaterialApp(
      title: 'GymApp',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: const ColorScheme.dark(
          primary: neonGreen,
          secondary: neonGreen,
          surface: cardBackground,
          background: darkBackground,
          onPrimary: Colors.black,
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: neonGreen,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
          iconTheme: IconThemeData(color: neonGreen),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: neonGreen,
            foregroundColor: Colors.black,
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
        ),
        cardTheme: CardTheme(
          color: cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: neonGreen.withOpacity(0.2), width: 1),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

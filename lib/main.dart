import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/presentation/widgets/textured_background.dart';
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
    const neonGreen = Color(0xFF00FF66);
    const darkBackground = Color(0xFF101214);
    const cardBackground = Color(0xFF1A1D21);

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
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: neonGreen,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: [
              Shadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 4),
            ],
          ),
          iconTheme: IconThemeData(color: neonGreen),
        ),
      ),
      builder: (context, child) {
        return TexturedBackground(
          child: child ?? const SizedBox(),
        );
      },
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Scelta del colore principale dell'app.
class SceltaColore extends StatelessWidget {
  const SceltaColore({super.key});

  @override
  Widget build(BuildContext context) {
    final scuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: coloreSuperficie(context), borderRadius: BorderRadius.circular(24)),
      child: ValueListenableBuilder<int>(
        valueListenable: ThemeController.colore,
        builder: (context, scelto, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colore dell\'app', style: GoogleFonts.oswald(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              coloreAppAttuale.nome,
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < paletteApp.length; i++)
                  Semantics(
                    label: paletteApp[i].nome,
                    button: true,
                    selected: i == scelto,
                    child: GestureDetector(
                      onTap: () => ThemeController.cambiaColore(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: scuro ? paletteApp[i].scuro : paletteApp[i].chiaro,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i == scelto ? (scuro ? Colors.white : Colors.black) : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: i == scelto ? const Icon(Icons.check, color: Colors.black) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

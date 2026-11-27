import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Pulsante ufficiale "Accedi con Google" (obbligatorio sul web).
Widget pulsanteGoogleWeb() => SizedBox(
      height: 48,
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.filledBlack,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.signinWith,
          shape: web.GSIButtonShape.pill,
          locale: 'it',
        ),
      ),
    );

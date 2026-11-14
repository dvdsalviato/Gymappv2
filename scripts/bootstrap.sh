#!/usr/bin/env bash
# Rigenera la cartella android/ (che non sta nel repo) e la prepara per la build.
# Uso: bash scripts/bootstrap.sh telefono|orologio
set -euo pipefail

VARIANTE="${1:-telefono}"
cd "$(dirname "$0")/.."

echo "=== Bootstrap GymApp ($VARIANTE) ==="

# Salva lib e assets per sicurezza: flutter create non deve toccarli.
rm -rf /tmp/gym_salva && mkdir -p /tmp/gym_salva
cp -r lib assets /tmp/gym_salva/

rm -rf android
# Pacchetto com.example.gymapp_v2: lo stesso usato finora con Codemagic,
# così l'app si aggiorna sopra quella installata e l'accesso Google resta valido.
flutter create . --org com.example --platforms android --no-pub

# Ripristina lib e assets originali (rimuove l'eventuale test di esempio creato).
rm -rf lib assets
cp -r /tmp/gym_salva/lib /tmp/gym_salva/assets .
rm -f test/widget_test.dart

python3 scripts/patch_android.py "$VARIANTE"

flutter pub get

echo "=== Versioni delle librerie (controllo) ==="
awk '/^  (shared_preferences_android|shared_preferences|jni):/{n=$1} n && /version:/{print n, $2; n=""}' pubspec.lock || true

dart run flutter_launcher_icons

echo "=== Bootstrap completato ==="

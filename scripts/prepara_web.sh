#!/usr/bin/env bash
# Prepara la cartella web/ (non sta nel repo): file di Flutter, SQLite in
# WebAssembly, nome, colori e icone di Gymapp.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create . --org com.example --platforms web --no-pub
rm -f test/widget_test.dart
flutter pub get
# Copia sqlite3.wasm e il service worker di sqflite in web/
dart run sqflite_common_ffi_web:setup

# Icone dal logo dell'app (ImageMagick è già sui server di GitHub)
for lato in 192 512; do
  convert assets/icon.png -resize ${lato}x${lato} "web/icons/Icon-${lato}.png"
  convert assets/icon.png -resize ${lato}x${lato} "web/icons/Icon-maskable-${lato}.png"
done
convert assets/icon.png -resize 32x32 web/favicon.png

python3 - <<'PY'
import json, re
m = json.load(open('web/manifest.json'))
m.update({
    'name': 'Gymapp',
    'short_name': 'Gymapp',
    'description': 'Le tue schede, i tuoi progressi, il tuo coach.',
    'background_color': '#0A0A0C',
    'theme_color': '#0A0A0C',
    'display': 'standalone',
    'orientation': 'portrait',
})
json.dump(m, open('web/manifest.json', 'w'), indent=2, ensure_ascii=False)

h = open('web/index.html').read()
h = re.sub(r'<title>.*?</title>', '<title>Gymapp</title>', h, flags=re.S)
h = re.sub(r'(name="apple-mobile-web-app-title" content=")[^"]*', r'\1Gymapp', h)
h = re.sub(r'(name="description" content=")[^"]*', r'\1Le tue schede, i tuoi progressi, il tuo coach.', h)
if 'name="theme-color"' not in h:
    h = h.replace('</head>', '  <meta name="theme-color" content="#0A0A0C">\n</head>')
open('web/index.html', 'w').write(h)
PY
echo "=== Web pronto ==="

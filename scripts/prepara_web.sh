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

# Icone dal logo dell'app: ridimensionate con Pillow; se non si riesce a
# installarlo si copia il logo così com'è (il browser lo scala da solo).
pip install --quiet pillow 2>/dev/null || true
python3 - <<'PY' || { for f in web/icons/Icon-192.png web/icons/Icon-512.png web/icons/Icon-maskable-192.png web/icons/Icon-maskable-512.png web/icons/apple-touch-icon.png web/favicon.png; do cp assets/icon.png "$f"; done; }
from PIL import Image, ImageDraw, ImageFilter
logo = Image.open('assets/icon.png').convert('RGB')
# Colore di sfondo preso dai bordi del logo, così il riempimento non si nota.
w, h = logo.size
px = [logo.getpixel((x, y)) for x, y in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]
sfondo = tuple(sum(c[i] for c in px) // len(px) for i in range(3))

def con_margine(lato, quota):
    tela = Image.new('RGB', (lato, lato), sfondo)
    interno = int(lato * quota)
    # Bordi sfumati: la texture del logo si fonde col fondo senza "quadrato" visibile.
    maschera = Image.new('L', (interno, interno), 0)
    m = int(interno * 0.07)
    ImageDraw.Draw(maschera).rounded_rectangle((m, m, interno - m, interno - m), radius=m * 2, fill=255)
    maschera = maschera.filter(ImageFilter.GaussianBlur(m * 0.6))
    tela.paste(logo.resize((interno, interno), Image.LANCZOS), ((lato - interno) // 2, (lato - interno) // 2), maschera)
    return tela

for lato in (192, 512):
    # Icone normali: leggero margine (Chrome/desktop le mostrano intere).
    con_margine(lato, 0.96).save(f'web/icons/Icon-{lato}.png')
    # Maskable: Android ritaglia un cerchio, il logo deve stare nella zona sicura (80%).
    con_margine(lato, 0.80).save(f'web/icons/Icon-maskable-{lato}.png')
# iPhone: icona dedicata 180x180 (iOS arrotonda solo gli angoli).
logo.resize((180, 180), Image.LANCZOS).save('web/icons/apple-touch-icon.png')
logo.resize((32, 32), Image.LANCZOS).save('web/favicon.png')
PY

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
h = re.sub(r'<link rel="apple-touch-icon"[^>]*>', '<link rel="apple-touch-icon" sizes="180x180" href="icons/apple-touch-icon.png">', h)
h = re.sub(r'(name="description" content=")[^"]*', r'\1Le tue schede, i tuoi progressi, il tuo coach.', h)
if 'name="theme-color"' not in h:
    h = h.replace('</head>', '  <meta name="theme-color" content="#0A0A0C">\n</head>')
open('web/index.html', 'w').write(h)
PY
echo "=== Web pronto ==="

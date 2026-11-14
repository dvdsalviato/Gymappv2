#!/usr/bin/env python3
"""Modifica i file Android generati da `flutter create`.

Riporta qui tutte le modifiche che prima faceva codemagic.yaml:
nome dell'app, permessi, servizio notifiche, icona notifica, Wear OS,
compileSdk 36 per le librerie, desugaring, Java 17, firma fissa, lint.

Uso: python3 scripts/patch_android.py telefono|orologio
"""
import re
import sys
from pathlib import Path

VARIANTE = sys.argv[1] if len(sys.argv) > 1 else "telefono"
if VARIANTE not in ("telefono", "orologio"):
    sys.exit(f"Variante sconosciuta: {VARIANTE}")

ANDROID = Path("android")
MANIFEST = ANDROID / "app/src/main/AndroidManifest.xml"
RES = ANDROID / "app/src/main/res"


def leggi(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def scrivi(p: Path, testo: str) -> None:
    p.write_text(testo, encoding="utf-8")


def primo_esistente(*percorsi: str) -> Path:
    for p in percorsi:
        if Path(p).exists():
            return Path(p)
    sys.exit(f"Nessuno di questi file esiste: {percorsi}")


def sostituisci_uno(testo: str, schema: str, nuovo: str, cosa: str, flags=0) -> str:
    risultato, n = re.subn(schema, nuovo, testo, count=1, flags=flags)
    if n == 0:
        sys.exit(f"ERRORE patch: non trovato '{cosa}'")
    return risultato


# ---------------------------------------------------------------------------
# 1) build.gradle di progetto: compileSdk 36 per tutte le librerie
# ---------------------------------------------------------------------------
radice = primo_esistente("android/build.gradle.kts", "android/build.gradle")
testo = leggi(radice)
if "alzaCompileSdk" not in testo and "compileSdkVersion 36" not in testo:
    if radice.suffix == ".kts":
        testo += '''

// Alcuni pacchetti (file_picker, share_plus...) sono compilati con un Android
// più vecchio di quello richiesto dalle librerie nuove: si alza per tutti.
subprojects {
    fun alzaCompileSdk() {
        try {
            val android = extensions.findByName("android")
            if (android != null && plugins.hasPlugin("com.android.library")) {
                android.javaClass.getMethod("compileSdkVersion", Int::class.java).invoke(android, 36)
            }
        } catch (e: Exception) {
            println("compileSdk non modificato per " + name + ": " + e)
        }
    }
    if (state.executed) alzaCompileSdk() else afterEvaluate { alzaCompileSdk() }
}
'''
    else:
        testo += '''

subprojects {
    afterEvaluate { project ->
        if (project.plugins.hasPlugin("com.android.library")) {
            project.android { compileSdkVersion 36 }
        }
    }
}
'''
    scrivi(radice, testo)
print(f"OK compileSdk 36 librerie ({radice})")

# ---------------------------------------------------------------------------
# 2) build.gradle dell'app: firma, desugaring, Java 17, lint
# ---------------------------------------------------------------------------
app = primo_esistente("android/app/build.gradle.kts", "android/app/build.gradle")
testo = leggi(app)
kts = app.suffix == ".kts"

if kts:
    # Lettura di key.properties (scritto dal workflow) prima del blocco android
    testo = sostituisci_uno(
        testo,
        r"^android \{",
        '''val keyProps = java.util.Properties()
val keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyProps.load(java.io.FileInputStream(keyPropsFile))
}

android {
    signingConfigs {
        create("release") {
            storeFile = file(keyProps.getProperty("storeFile") ?: "upload-keystore.jks")
            storePassword = keyProps.getProperty("storePassword")
            keyAlias = keyProps.getProperty("keyAlias")
            keyPassword = keyProps.getProperty("keyPassword")
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
''',
        "android { (app kts)",
        flags=re.M,
    )
    testo = testo.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
    testo = sostituisci_uno(
        testo,
        r"compileOptions \{",
        "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
        "compileOptions (kts)",
    )
    testo += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
else:
    testo = sostituisci_uno(
        testo,
        r"^android \{",
        '''def keyProps = new Properties()
def keyPropsFile = rootProject.file("key.properties")
if (keyPropsFile.exists()) {
    keyPropsFile.withInputStream { keyProps.load(it) }
}

android {
    signingConfigs {
        release {
            storeFile file(keyProps["storeFile"] ?: "upload-keystore.jks")
            storePassword keyProps["storePassword"]
            keyAlias keyProps["keyAlias"]
            keyPassword keyProps["keyPassword"]
        }
    }

    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
''',
        "android { (app groovy)",
        flags=re.M,
    )
    testo = re.sub(r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig signingConfigs.release", testo)
    testo = sostituisci_uno(
        testo,
        r"compileOptions \{",
        "compileOptions {\n        coreLibraryDesugaringEnabled true",
        "compileOptions (groovy)",
    )
    testo += '\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.1.4"\n}\n'

testo = testo.replace("VERSION_1_8", "VERSION_17").replace("VERSION_11", "VERSION_17")
testo = re.sub(r"(jvmTarget\s*=\s*)[\"'][0-9.]+[\"']", r'\1"17"', testo)
testo = testo.replace("JvmTarget.JVM_11", "JvmTarget.JVM_17")
scrivi(app, testo)

if 'getByName("release")' not in testo and "signingConfigs.release" not in testo:
    sys.exit("ERRORE patch: la build release non usa la firma release")
print(f"OK firma fissa, desugaring, Java 17, lint ({app})")

# ---------------------------------------------------------------------------
# 3) AndroidManifest
# ---------------------------------------------------------------------------
m = leggi(MANIFEST)

etichetta = "Gymapp Orologio" if VARIANTE == "orologio" else "Gymapp"
m = re.sub(r'android:label="[^"]*"', f'android:label="{etichetta}"', m, count=1)


def aggiungi_permesso(manifest: str, nome: str) -> str:
    if f'android:name="{nome}"' in manifest:
        return manifest
    return manifest.replace(
        "<application", f'<uses-permission android:name="{nome}"/>\n    <application', 1
    )


if VARIANTE == "telefono":
    for perm in (
        "android.permission.INTERNET",
        "android.permission.CAMERA",
        "android.permission.FOREGROUND_SERVICE",
        "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
        "android.permission.POST_NOTIFICATIONS",
    ):
        m = aggiungi_permesso(m, perm)

    if "flutterlocalnotifications.ForegroundService" not in m:
        m = m.replace(
            "</application>",
            '''    <service android:name="com.dexterous.flutterlocalnotifications.ForegroundService" android:exported="false" android:stopWithTask="true" android:foregroundServiceType="specialUse">
            <property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="Cronometro di allenamento"/>
        </service>
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
    </application>''',
            1,
        )
else:
    if "android.hardware.type.watch" not in m:
        m = m.replace(
            "<application",
            '<uses-feature android:name="android.hardware.type.watch"/>\n    <application',
            1,
        )
    if "wearable.standalone" not in m:
        m = re.sub(
            r"(<application[^>]*>)",
            r'''\1
        <uses-library android:name="com.google.android.wearable" android:required="false"/>
        <meta-data android:name="com.google.android.wearable.standalone" android:value="false"/>''',
            m,
            count=1,
        )

scrivi(MANIFEST, m)
print(f"OK manifest ({VARIANTE}, etichetta '{etichetta}')")

# ---------------------------------------------------------------------------
# 4) Icona e risorse della notifica (solo telefono)
# ---------------------------------------------------------------------------
if VARIANTE == "telefono":
    (RES / "drawable").mkdir(parents=True, exist_ok=True)
    (RES / "raw").mkdir(parents=True, exist_ok=True)
    scrivi(
        RES / "drawable/ic_stat_gym.xml",
        '''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M20.57,14.86L22,13.43L20.57,12L17,15.57L8.43,7L12,3.43L10.57,2L9.14,3.43L7.71,2L5.57,4.14L4.14,2.71L2.71,4.14l1.43,1.43L2,7.71l1.43,1.43L2,10.57L3.43,12L7,8.43L15.57,17L12,20.57L13.43,22l1.43,-1.43L16.29,22l2.14,-2.14l1.43,1.43l1.43,-1.43l-1.43,-1.43L22,16.29z"/>
</vector>
''',
    )
    scrivi(
        RES / "raw/keep.xml",
        '''<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools" tools:keep="@drawable/ic_stat_gym,@mipmap/ic_launcher" />
''',
    )
    print("OK icona notifica")

print("=== Patch Android completate ===")

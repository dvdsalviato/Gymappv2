import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Versione web: SQLite in WebAssembly (i dati restano nel browser).
void impostaDatabaseWeb() {
  databaseFactory = databaseFactoryFfiWeb;
}

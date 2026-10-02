import 'package:flutter/material.dart';
import '../data/catalogo_esercizi.dart';

Future<EsercizioCatalogo?> mostraCatalogoEsercizi(BuildContext context) {
  return showModalBottomSheet<EsercizioCatalogo>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CatalogoSheet(),
  );
}

class _CatalogoSheet extends StatefulWidget {
  const _CatalogoSheet();

  @override
  State<_CatalogoSheet> createState() => _CatalogoSheetState();
}

class _CatalogoSheetState extends State<_CatalogoSheet> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final categorie = <String, List<EsercizioCatalogo>>{};
    for (final e in catalogoEsercizi) {
      if (_filtro.isNotEmpty && !e.nome.toLowerCase().contains(_filtro.toLowerCase())) {
        continue;
      }
      categorie.putIfAbsent(e.categoria, () => []).add(e);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Catalogo esercizi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(hintText: 'Cerca esercizio...'),
                onChanged: (v) => setState(() => _filtro = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: categorie.isEmpty
                    ? Center(
                        child: Text(
                          'Nessun esercizio trovato',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView(
                        controller: scrollController,
                        children: categorie.entries.map((cat) {
                          return ExpansionTile(
                            title: Text(cat.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                            initiallyExpanded: _filtro.isNotEmpty,
                            children: cat.value.map((e) {
                              return ListTile(
                                title: Text(e.nome),
                                onTap: () => Navigator.pop(context, e),
                              );
                            }).toList(),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

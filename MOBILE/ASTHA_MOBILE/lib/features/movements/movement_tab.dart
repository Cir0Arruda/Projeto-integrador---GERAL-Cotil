// ============================================================================
// ★ ABA DE MOVIMENTAÇÃO DE ESTOQUE (MOVEMENT_TAB.DART) ★
// Permite que o operador escolha se vai dar ENTRADA ou SAÍDA de peças! (✿◠‿◠)
// Conecta com o formulário inteligente (MovementForm) que envia tudo pra API :3
// ============================================================================

import 'package:flutter/material.dart';

import 'movement_form.dart';

// O seletor de Entrada ou Saída com botãozinhos segmentados :3
class MovementTab extends StatefulWidget {
  const MovementTab({super.key});

  @override
  State<MovementTab> createState() => _MovementTabState();
}

class _MovementTabState extends State<MovementTab> {
  // true = dando entrada de mercadoria, false = dando baixa/saída (｡•̀ᴗ-)✧
  bool _entry = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Entrada'), icon: Icon(Icons.add_circle_outline)),
              ButtonSegment(value: false, label: Text('Saída'), icon: Icon(Icons.remove_circle_outline)),
            ],
            selected: {_entry},
            onSelectionChanged: (value) => setState(() => _entry = value.first),
          ),
        ),
        Expanded(child: MovementForm(key: ValueKey(_entry), entry: _entry)),
      ],
    );
  }
}

class MovementScreen extends StatelessWidget {
  const MovementScreen({super.key, required this.entry, this.initialCode});

  final bool entry;
  final String? initialCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(entry ? 'Entrada de material' : 'Saída de material')),
      body: MovementForm(entry: entry, initialCode: initialCode),
    );
  }
}

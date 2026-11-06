import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../models/eam_models.dart';

class CounterReadingDialog extends StatefulWidget {
  const CounterReadingDialog({
    super.key,
    required this.asset,
    required this.onSave,
  });
  final AssetItem asset;
  final Future<void> Function(double? hours, double? cycles) onSave;

  @override
  State<CounterReadingDialog> createState() => _CounterReadingDialogState();
}

class _CounterReadingDialogState extends State<CounterReadingDialog> {
  late final _hours = TextEditingController(
    text: widget.asset.operatingHours > 0
        ? widget.asset.operatingHours.toString().replaceAll('.', ',')
        : '',
  );
  late final _cycles = TextEditingController(
    text: widget.asset.operatingCycles > 0
        ? widget.asset.operatingCycles.toString().replaceAll('.', ',')
        : '',
  );
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    _cycles.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final hours = parseDecimal(_hours.text),
        cycles = parseDecimal(_cycles.text);
    if ((hours == null && cycles == null) ||
        (_hours.text.trim().isNotEmpty && hours == null) ||
        (_cycles.text.trim().isNotEmpty && cycles == null) ||
        (hours != null &&
            (hours < widget.asset.operatingHours || hours > 1e9)) ||
        (cycles != null &&
            (cycles < widget.asset.operatingCycles || cycles > 1e9))) {
      setState(
        () => _error =
            'Informe ao menos uma leitura válida, sem retroceder o contador (máximo 1 bilhão).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(hours, cycles);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Não foi possível registrar a leitura. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('Leitura de medidores: ${widget.asset.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _hours,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Horímetro acumulado (horas)',
                hintText: 'Ex.: 1500,5',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cycles,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Ciclos acumulados',
                hintText: 'Ex.: 45000',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar leitura'),
        ),
      ],
    ),
  );
}

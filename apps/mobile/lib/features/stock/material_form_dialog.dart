// ============================================================================
// ★ FORMULÁRIO DE CADASTRO E EDIÇÃO DE MATERIAIS (MATERIAL_FORM_DIALOG.DART) ★
// Abre a janelinha modal para cadastrar uma nova peça ou editar uma existente! (✿◠‿◠)
// 1) Se for novo: chama POST /api/materials na API :3
// 2) Se for edição: chama PUT /api/materials/:code no servidor (｡•̀ᴗ-)✧
// 3) Suporta código, nome, marca, máquina, setor, preço, quantidade mínima e código de barras! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/dialogs.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../state/warehouse_controller.dart';

// O diálogo bonito em formato de modal para salvar o item :3
class MaterialFormDialog extends StatefulWidget {
  const MaterialFormDialog({super.key, this.material});

  // Se vier com material preenchido, é EDIÇÃO. Se vier null, é CADASTRO NOVO! (o^▽^o)
  final MaterialItem? material;

  static Future<bool?> show(BuildContext context, {MaterialItem? material}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MaterialFormDialog(material: material),
    );
  }

  @override
  State<MaterialFormDialog> createState() => _MaterialFormDialogState();
}

class _MaterialFormDialogState extends State<MaterialFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _sectorCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minQtyCtrl;
  late final TextEditingController _maxQtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _originCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _machineryCtrl;
  late final TextEditingController _notesCtrl;
  late bool _interchangeable;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.material;
    _codeCtrl = TextEditingController(text: m?.code ?? '');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    _brandCtrl = TextEditingController(text: m?.brand ?? '');
    _modelCtrl = TextEditingController(text: m?.model ?? '');
    _sectorCtrl = TextEditingController(text: m?.sector ?? 'Assembly');
    _locationCtrl = TextEditingController(text: m?.location ?? '');
    _qtyCtrl = TextEditingController(
      text: m != null ? m.quantity.toString() : '0',
    );
    _minQtyCtrl = TextEditingController(
      text: m != null ? m.minQty.toString() : '5',
    );
    _maxQtyCtrl = TextEditingController(
      text: m != null ? m.maxQty.toString() : '50',
    );
    _priceCtrl = TextEditingController(
      text: m != null ? m.unitPrice.toString() : '0',
    );
    _unitCtrl = TextEditingController(text: m?.unit ?? 'UN');
    _originCtrl = TextEditingController(text: m?.originCountry ?? '');
    _barcodeCtrl = TextEditingController(text: m?.barcode ?? '');
    _machineryCtrl = TextEditingController(text: m?.machinery ?? '');
    _notesCtrl = TextEditingController(text: m?.notes ?? '');
    _interchangeable = m?.interchangeable ?? false;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _sectorCtrl.dispose();
    _locationCtrl.dispose();
    _qtyCtrl.dispose();
    _minQtyCtrl.dispose();
    _maxQtyCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _originCtrl.dispose();
    _barcodeCtrl.dispose();
    _machineryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    final numbers = <String, double>{};
    for (final field in [
      ('quantity', 'Quantidade', _qtyCtrl, 3),
      ('min_qty', 'Estoque mínimo', _minQtyCtrl, 3),
      ('max_qty', 'Estoque máximo', _maxQtyCtrl, 3),
      ('unit_price', 'Preço', _priceCtrl, 2),
    ]) {
      final text = field.$3.text.trim();
      final value = text.isEmpty ? 0.0 : parseDecimal(text);
      final scale = field.$4 == 2 ? 100 : 1000;
      if (value == null ||
          value < 0 ||
          value > 1e9 ||
          (value * scale - (value * scale).round()).abs() > 0.000001) {
        setState(
          () => _error =
              '${field.$2}: informe um número de 0 a 1 bilhão, com até ${field.$4} casas decimais. Use vírgula ou ponto, sem separador de milhar.',
        );
        return;
      }
      numbers[field.$1] = value;
    }
    if (_codeCtrl.text.trim().length > 20) {
      setState(() => _error = 'O código deve ter até 20 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = context.read<WmsRepository>();
    final warehouseId = context.read<WarehouseController>().selectedId;

    final payload = <String, dynamic>{
      'description': _descCtrl.text.trim(),
      'brand': _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      'model': _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      'sector': _sectorCtrl.text.trim().isEmpty
          ? 'Assembly'
          : _sectorCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      ...numbers,
      'unit': _unitCtrl.text.trim().isEmpty ? 'UN' : _unitCtrl.text.trim(),
      'origin_country': _originCtrl.text.trim().isEmpty
          ? null
          : _originCtrl.text.trim(),
      'barcode': _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      'machinery': _machineryCtrl.text.trim().isEmpty
          ? null
          : _machineryCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      'interchangeable': _interchangeable,
      if (warehouseId != null) 'warehouse_id': warehouseId,
    };

    if (_codeCtrl.text.trim().isNotEmpty) {
      payload['code'] = _codeCtrl.text.trim().toUpperCase();
    }

    try {
      if (widget.material == null) {
        await repo.createMaterial(payload);
      } else {
        await repo.updateMaterial(widget.material!.code, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on QueuedOperationException catch (e) {
      if (mounted) {
        showToast(context, e.message);
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.material != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: AppColors.brandText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Material' : 'Novo Material',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _descCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descrição do Material *',
                            hintText: 'Ex.: Motor Trifásico 220V',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Descrição obrigatória'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _codeCtrl,
                                readOnly: isEditing,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: InputDecoration(
                                  labelText: isEditing
                                      ? 'Código'
                                      : 'Código (opcional)',
                                  hintText: 'MERB-...',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _unitCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Unidade',
                                  hintText: 'UN, KG, M',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _brandCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Marca',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _modelCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Modelo',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _sectorCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Setor',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _locationCtrl,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                  labelText: 'Posição / Local',
                                  hintText: 'SH-1-N1-P1',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Quantidade',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _minQtyCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Estoque Mínimo',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Preço (R\$)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _barcodeCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Código de Barras',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _originCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'País de Origem',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _machineryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Máquina Vinculada',
                            hintText: 'Ex.: Centro CNC 01',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Observações',
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Peça Intercambiável',
                            style: TextStyle(fontSize: 14),
                          ),
                          value: _interchangeable,
                          onChanged: (v) =>
                              setState(() => _interchangeable = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Salvar' : 'Cadastrar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ★ FORMULÁRIO DE ENTRADA E SAÍDA DE ESTOQUE (MOVEMENT_FORM.DART) ★
// É aqui que os operadores registram a movimentação física das peças! (✿◠‿◠)
// 1) Busca o material pelo código na API: GET /api/materials/:code :3
// 2) Mostra fotinho e saldo atual do item em tempo real (｡•̀ᴗ-)✧
// 3) Envia a movimentação pra API: POST /api/movements/entry ou /exit! ヽ(>∀<☆)ノ
// 4) Atualiza o saldo do estoque automaticamente! (TwT)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../state/session_controller.dart';
import '../../state/warehouse_controller.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/material_thumb.dart';
import 'material_picker.dart';
import 'material_qr.dart';
import 'withdrawal_approval.dart';
import '../../core/offline_store.dart' show operationId;

// Formulário inteligente de movimentação de materiais :3
class MovementForm extends StatefulWidget {
  const MovementForm({super.key, required this.entry, this.initialCode});

  // true = dando entrada (chegou carga!), false = dando saída (peça usada) (o^▽^o)
  final bool entry;
  // Código pré-preenchido caso tenha vindo da tela de detalhes de um item :3
  final String? initialCode;

  @override
  State<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<MovementForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  final _quantity = TextEditingController();
  final _invoice = TextEditingController();
  final _reason = TextEditingController();

  MaterialItem? _material;
  String? _lookupError;
  bool _looking = false;
  bool _busy = false;
  String? _withdrawalId, _withdrawalFields;

  Future<void> _scan() async {
    final org = context.read<SessionController>().user?.orgId;
    if (org == null) return;
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MaterialQrScanner(org: org)),
    );
    if (!mounted || code == null) return;
    _code.text = code;
    await _lookup(allWarehouses: true);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookup();
      });
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _quantity.dispose();
    _invoice.dispose();
    _reason.dispose();
    super.dispose();
  }

  // ==========================================================================
  // BUSCA DO MATERIAL NA API: GET /api/materials/:code
  // Consulta se o código existe no servidor e traz todos os dados da peça :3
  // ==========================================================================
  Future<void> _lookup({bool allWarehouses = false}) async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    final repository = context.read<WmsRepository>();
    final warehouseId = context.read<WarehouseController>().selectedId;
    setState(() {
      _looking = true;
      _lookupError = null;
    });
    try {
      final item = await repository.findMaterial(
        code,
        warehouseId: allWarehouses ? null : warehouseId,
      );
      if (!mounted) return;
      setState(() {
        _material = item;
        _lookupError = item == null ? 'Material não encontrado.' : null;
      });
      final whId = item?.warehouseId;
      if (whId != null) {
        final ctrl = context.read<WarehouseController>();
        if (ctrl.selectedId != whId) {
          ctrl.selectById(whId);
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _material = null;
          _lookupError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _material = null;
          _lookupError = 'Falha ao consultar material.';
        });
      }
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<void> _pick() async {
    final picked = await showMaterialPicker(context);
    if (picked == null) return;
    _code.text = picked.code;
    setState(() {
      _material = picked;
      _lookupError = null;
    });
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final material = _material;
    if (material == null) {
      showToast(context, 'Selecione um material válido.', error: true);
      return;
    }
    final repository = context.read<WmsRepository>();
    setState(() => _busy = true);
    try {
      final quantity = parseDecimal(_quantity.text)!;
      String? password;
      if (!widget.entry) {
        password = await requestWithdrawalApproval(
          context,
          material.code,
          quantity,
        );
        if (password == null || !mounted) return;
        final fields = '${material.code}:$quantity:${_optional(_reason)}';
        if (fields != _withdrawalFields) {
          _withdrawalId = operationId();
          _withdrawalFields = fields;
        }
      }
      final result = await repository.registerMovement(
        entry: widget.entry,
        code: material.code,
        quantity: quantity,
        password: password,
        withdrawalId: _withdrawalId,
        nfNumber: _optional(_invoice),
        reason: _optional(_reason),
      );
      if (!mounted) return;
      showToast(
        context,
        '${widget.entry ? 'Entrada' : 'Saída'} registrada. Novo saldo: ${formatQuantity(result.newStock)}',
      );
      _quantity.clear();
      _invoice.clear();
      _reason.clear();
      _withdrawalId = null;
      _withdrawalFields = null;
      await _lookup();
    } on QueuedOperationException catch (error) {
      if (mounted) {
        showToast(context, error.message);
        _quantity.clear();
        _invoice.clear();
        _reason.clear();
      }
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message, error: true);
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Não foi possível concluir. Confira o histórico antes de repetir.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canMove = context.select<SessionController, bool>(
      (s) => s.user?.canMove ?? false,
    );
    final accent = widget.entry ? AppColors.brand : AppColors.danger;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!canMove)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Seu perfil não possui permissão para registrar movimentações.',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onFieldSubmitted: (_) => _lookup(),
                  decoration: InputDecoration(
                    labelText: 'Código do material',
                    errorText: _lookupError,
                    suffixIcon: _looking
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _lookup,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _busy ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Ler QR Code',
              ),
              IconButton.filledTonal(
                onPressed: _pick,
                icon: const Icon(Icons.list_alt),
                tooltip: 'Escolher da lista',
                style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
              ),
            ],
          ),
          if (_material != null) ...[
            const SizedBox(height: 12),
            _MaterialSummary(item: _material!),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _quantity,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantidade',
              suffixText: _material?.unit,
            ),
            validator: (value) {
              final number = parseDecimal(value ?? '');
              if (number == null || number <= 0) {
                return 'Informe uma quantidade maior que zero';
              }
              return null;
            },
          ),
          if (widget.entry) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _invoice,
              decoration: const InputDecoration(
                labelText: 'Nota fiscal (opcional)',
              ),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _reason,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: widget.entry
                  ? 'Motivo (opcional)'
                  : 'Centro de custo / OS (opcional)',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_busy || !canMove) ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: accent),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.entry ? 'REGISTRAR ENTRADA' : 'REGISTRAR SAÍDA'),
          ),
        ],
      ),
    );
  }
}

class _MaterialSummary extends StatelessWidget {
  const _MaterialSummary({required this.item});

  final MaterialItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: MaterialThumb(item: item),
        title: Text(
          item.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Saldo atual: ${formatQuantity(item.quantity)} ${item.unit}',
        ),
      ),
    );
  }
}

// ============================================================================
// ★ PAINEL DE DETALHES DO MATERIAL (MATERIAL_DETAIL_SHEET.DART) ★
// A gaveta deslizante completa que abre quando você toca em qualquer peça do estoque! (✿◠‿◠)
// 1) Mostra todos os detalhes técnicos do objeto vindo da API :3
// 2) Carrega os arquivos/anexos chamando GET /api/materials/:code/files (｡•̀ᴗ-)✧
// 3) Permite editar, excluir (DELETE /api/materials/:code) ou dar entrada/saída rápida! ヽ(>∀<☆)ノ
// ============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../state/session_controller.dart';
import '../movements/material_qr.dart';
import 'material_model_page.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/wms_models.dart';
import '../../repositories/wms_repository.dart';
import '../../widgets/cards.dart';
import '../movements/movement_tab.dart';
import '../shared/labels.dart';
import '../warehouse/warehouse_map_page.dart';
import 'material_form_dialog.dart';

// O painel deslizante tipo folha inferior (BottomSheet) :3
class MaterialDetailSheet extends StatefulWidget {
  const MaterialDetailSheet({super.key, required this.item});

  // O item de material com todos os dados da API! (o^▽^o)
  final MaterialItem item;

  static Future<bool?> show(BuildContext context, MaterialItem item) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialDetailSheet(item: item),
    );
  }

  @override
  State<MaterialDetailSheet> createState() => _MaterialDetailSheetState();
}

class _MaterialDetailSheetState extends State<MaterialDetailSheet> {
  late MaterialItem _item = widget.item;
  int _tab = 0;
  List<MaterialFile>? _files;
  bool _loadingFiles = false;
  String? _filesError;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loadingFiles = true;
      _filesError = null;
    });
    try {
      final repo = context.read<WmsRepository>();
      final files = await repo.materialFiles(_item.code);
      if (mounted) {
        setState(() {
          _files = files;
          _loadingFiles = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingFiles = false;
          _filesError = 'Não foi possível carregar os anexos.';
        });
      }
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _item.code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Código "${_item.code}" copiado!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _locateOnMap() async {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => WarehouseMapPage(
          initialWarehouseId: _item.warehouseId,
          highlightLocation: _item.location,
        ),
      ),
    );
  }

  void _openModel([MaterialFile? file]) {
    final models = (_files ?? []).where((file) => file.is3D).toList();
    models.sort(
      (a, b) => (a.category == 'product_3d' ? 0 : 1).compareTo(
        b.category == 'product_3d' ? 0 : 1,
      ),
    );
    if (file == null && models.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MaterialModelPage(code: _item.code, file: file ?? models.first),
      ),
    );
  }

  void _showBarcodeDialog() {
    final user = context.read<SessionController>().user;
    if (user?.orgId == null) return;
    final payload = materialQrPayload(_item.code, user!.orgId!);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('QR Code do material'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: QrImageView(
                  data: payload,
                  backgroundColor: Colors.white,
                ),
              ),
              Text(
                _item.code,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'No aplicativo, abra Movimentar → Saída e leia este QR Code. Confira a quantidade e confirme com sua senha. No Android, a biometria cadastrada também é solicitada.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
            },
            child: const Text('Copiar conteúdo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MovementScreen(entry: false, initialCode: _item.code),
                ),
              );
            },
            child: const Text('Retirar item'),
          ),
        ],
      ),
    );
  }

  void _showImageZoom(String? base64Data, String? imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 520, maxWidth: 520),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: _buildDecodedImage(
                  base64Data,
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecodedImage(
    String? base64Data,
    String? imageUrl, {
    BoxFit fit = BoxFit.cover,
  }) {
    final raw =
        base64Data ??
        ((imageUrl != null && imageUrl.startsWith('data:image/'))
            ? imageUrl
            : null);
    if (raw != null && raw.isNotEmpty) {
      try {
        final comma = raw.indexOf(',');
        var payload = comma >= 0 ? raw.substring(comma + 1) : raw;
        payload = payload.replaceAll(RegExp(r'\s+'), '');
        final remainder = payload.length % 4;
        if (remainder != 0) {
          payload = payload.padRight(payload.length + (4 - remainder), '=');
        }
        final bytes = base64Decode(payload);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (_, _, _) => _imagePlaceholder(),
        );
      } catch (_) {}
    }
    if (imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.startsWith('data:image/')) {
      final resolved = imageUrl.startsWith('http')
          ? imageUrl
          : '${context.read<ApiClient>().baseUrl}$imageUrl';
      return Image.network(
        resolved,
        fit: fit,
        errorBuilder: (_, _, _) => _imagePlaceholder(),
      );
    }
    return _imagePlaceholder();
  }

  Widget _imagePlaceholder() => Container(
    color: AppColors.background,
    child: const Center(
      child: Icon(
        Icons.inventory_2_outlined,
        size: 48,
        color: AppColors.textMuted,
      ),
    ),
  );

  Future<void> _edit() async {
    final updated = await MaterialFormDialog.show(context, material: _item);
    if (updated == true && mounted) {
      final repo = context.read<WmsRepository>();
      final fresh = await repo.findMaterial(
        _item.code,
        warehouseId: _item.warehouseId,
      );
      if (fresh != null && mounted) {
        setState(() => _item = fresh);
        _loadFiles();
      } else if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir material?'),
        content: Text(
          'Deseja realmente remover o material "${_item.description}" (${_item.code})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final repo = context.read<WmsRepository>();
      try {
        await repo.deleteMaterial(_item.code);
        if (mounted) Navigator.of(context).pop(true);
      } on QueuedOperationException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
        }
      }
    }
  }

  void _move(bool entry) {
    final nav = Navigator.of(context);
    nav.pop(true);
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => MovementScreen(entry: entry, initialCode: _item.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = stockLevelColor(_item.level);
    final statusText = stockLevelLabel(_item.level);
    final has3d = _files?.any((f) => f.is3D) ?? false;
    final max = _item.maxQty;
    final pct = max > 0
        ? (_item.quantity / max).clamp(0.0, 1.0)
        : (_item.quantity > 0 ? 1.0 : 0.0);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _item.code,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  letterSpacing: 0.5,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                tooltip: 'Copiar código',
                                visualDensity: VisualDensity.compact,
                                onPressed: _copyCode,
                              ),
                            ],
                          ),
                          Text(
                            _item.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_2_outlined),
                      tooltip: 'QR Code para retirada',
                      onPressed: _showBarcodeDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                      onPressed: _edit,
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                      tooltip: 'Excluir',
                      onPressed: _delete,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Stack(
                      children: [
                        InkWell(
                          onTap: has3d
                              ? () => _openModel()
                              : () => _showImageZoom(
                                  _item.imageData,
                                  _item.imageUrl,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              color: AppColors.surface,
                              child: _buildDecodedImage(
                                _item.imageData,
                                _item.imageUrl,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Toque para ampliar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (has3d)
                          Positioned(
                            left: 8,
                            top: 8,
                            child: FilledButton.icon(
                              onPressed: () => _openModel(),
                              icon: const Icon(
                                Icons.view_in_ar_outlined,
                                size: 16,
                              ),
                              label: const Text('Modelo 3D'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'DISPONIBILIDADE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                StatusPill(label: statusText, color: color),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  formatQuantity(_item.quantity),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _item.unit,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 7,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mín: ${formatQuantity(_item.minQty)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                Text(
                                  max > 0
                                      ? 'Máx: ${formatQuantity(max)}'
                                      : 'Máx: —',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Valor Unitário',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(
                                        _item.unitPrice,
                                        currency: _item.currency,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Valor Total em Estoque',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      formatCurrency(
                                        _item.totalValue,
                                        currency: _item.currency,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _locateOnMap,
                      icon: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.brand,
                      ),
                      label: Text(
                        _item.location != null
                            ? 'Localizar no Mapa (${_item.location})'
                            : 'Localizar no Mapa do Armazém',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<int>(
                      segments: [
                        const ButtonSegment(
                          value: 0,
                          label: Text('Geral'),
                          icon: Icon(Icons.info_outline, size: 16),
                        ),
                        const ButtonSegment(
                          value: 1,
                          label: Text('Máquina'),
                          icon: Icon(
                            Icons.precision_manufacturing_outlined,
                            size: 16,
                          ),
                        ),
                        ButtonSegment(
                          value: 2,
                          label: Text(
                            _files != null && _files!.isNotEmpty
                                ? 'Anexos (${_files!.length})'
                                : 'Anexos',
                          ),
                          icon: const Icon(Icons.attach_file, size: 16),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (val) =>
                          setState(() => _tab = val.first),
                    ),
                    const SizedBox(height: 12),
                    if (_tab == 0) _buildGeneralTab(),
                    if (_tab == 1) _buildMachineryTab(),
                    if (_tab == 2) _buildFilesTab(),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _move(false),
                        icon: const Icon(Icons.remove_circle_outline),
                        label: const Text('Saída (-)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _move(true),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Entrada (+)'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return Column(
      children: [
        InfoRow(label: 'Código', value: _item.code),
        InfoRow(label: 'Marca', value: _item.brand),
        InfoRow(label: 'Modelo', value: _item.model),
        InfoRow(label: 'Setor', value: _item.sector),
        InfoRow(label: 'Localização / Posição', value: _item.location),
        if (_item.originCountry != null &&
            _item.originCountry!.trim().isNotEmpty)
          InfoRow(label: 'País de Origem', value: _item.originCountry),
        if (_item.barcode != null && _item.barcode!.trim().isNotEmpty)
          InfoRow(label: 'Código de Barras', value: _item.barcode),
        InfoRow(
          label: 'Intercambiável',
          value: _item.interchangeable ? 'Sim' : 'Não',
        ),
        if (_item.interchangeWith != null &&
            _item.interchangeWith!.trim().isNotEmpty)
          InfoRow(label: 'Peças Substitutas', value: _item.interchangeWith),
        if (_item.manufacturerUrl != null &&
            _item.manufacturerUrl!.trim().isNotEmpty)
          InfoRow(label: 'Site do Fabricante', value: _item.manufacturerUrl),
        if (_item.notes != null && _item.notes!.trim().isNotEmpty)
          InfoRow(label: 'Observações', value: _item.notes),
        if (_item.createdAt != null)
          InfoRow(label: 'Cadastrado em', value: formatDate(_item.createdAt)),
        if (_item.updatedAt != null)
          InfoRow(
            label: 'Última atualização',
            value: formatDate(_item.updatedAt),
          ),
      ],
    );
  }

  Widget _buildMachineryTab() {
    final mach = _item.machinery;
    final machImg = _item.machineryImage;
    final machDesc = _item.machineryDesc;
    final usage = _item.usageDesc;
    final notes = _item.notes;

    if ((mach == null || mach.trim().isEmpty) &&
        (machImg == null || machImg.trim().isEmpty) &&
        (machDesc == null || machDesc.trim().isEmpty) &&
        (usage == null || usage.trim().isEmpty) &&
        (notes == null || notes.trim().isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nenhuma informação de máquina ou aplicação vinculada.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (machImg != null && machImg.isNotEmpty) ...[
          InkWell(
            onTap: () => _showImageZoom(machImg, null),
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: double.infinity,
                color: AppColors.surface,
                child: _buildDecodedImage(machImg, null),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        InfoRow(label: 'Máquina Vinculada', value: mach ?? 'Não especificada'),
        if (machDesc != null && machDesc.trim().isNotEmpty)
          InfoRow(label: 'Detalhes da Máquina', value: machDesc),
        if (usage != null && usage.trim().isNotEmpty)
          InfoRow(label: 'Instruções de Uso / Aplicação', value: usage),
        if (notes != null && notes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFilesTab() {
    if (_loadingFiles) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filesError != null) {
      return Column(
        children: [
          Text(_filesError!),
          TextButton(
            onPressed: _loadFiles,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    final files = _files ?? [];
    final manual = _item.manualUrl;
    final manualName = _item.manualFilename;

    if (files.isEmpty && (manual == null || manual.isEmpty)) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 40,
                color: AppColors.textMuted,
              ),
              SizedBox(height: 8),
              Text(
                'Nenhum documento ou arquivo 3D anexado.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (manual != null && manual.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.brandLight,
                child: Icon(
                  Icons.menu_book_outlined,
                  color: AppColors.brandText,
                  size: 20,
                ),
              ),
              title: Text(manualName ?? 'Manual Técnico'),
              subtitle: const Text('Manual do fabricante'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () {
                Clipboard.setData(ClipboardData(text: manual));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link do manual copiado!')),
                );
              },
            ),
          ),
        ...files.map((file) {
          final is3d = file.is3D;
          final isPdf = file.filename.toLowerCase().endsWith('.pdf');
          final icon = is3d
              ? Icons.view_in_ar_outlined
              : (isPdf
                    ? Icons.picture_as_pdf_outlined
                    : Icons.insert_drive_file_outlined);
          final color = is3d
              ? AppColors.brand
              : (isPdf ? AppColors.danger : AppColors.textMuted);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Text(
                file.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (file.category != null) file.category,
                  '${(file.fileSize / 1024).toStringAsFixed(1)} KB',
                ].join(' · '),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: file.url != null
                  ? const Icon(Icons.download, size: 18)
                  : null,
              onTap: () {
                if (is3d) {
                  _openModel(file);
                  return;
                }
                final url = file.url;
                if (url != null) {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL do arquivo copiada!')),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

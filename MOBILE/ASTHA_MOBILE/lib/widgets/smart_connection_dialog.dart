// ============================================================================
// ★ CENTRAL DE DIAGNÓSTICO E CONEXÃO INTELIGENTE (SMART_CONNECTION_DIALOG.DART) ★
// Aqui o usuário pode:
// 1) Ver o status da conexão atual com medidor de latência em milissegundos :3
// 2) Apertar um botão pra escanear todas as redes e conectar na mais rápida! (｡•̀ᴗ-)✧
// 3) Colar o link do seu túnel ou IP de 4G se o celular tiver longe do PC! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/connection_service.dart';
import '../core/theme.dart';
import '../state/session_controller.dart';
import 'dialogs.dart';

// Abre a janelinha modal bonitinha da central de redes (✿◠‿◠)
Future<void> showSmartConnectionDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SmartConnectionDialog(),
  );
}

class SmartConnectionDialog extends StatefulWidget {
  const SmartConnectionDialog({super.key});

  @override
  State<SmartConnectionDialog> createState() => _SmartConnectionDialogState();
}

class _SmartConnectionDialogState extends State<SmartConnectionDialog> {
  final _customUrlCtrl = TextEditingController();
  bool _testingCustom = false;
  String? _customError;

  @override
  void dispose() {
    _customUrlCtrl.dispose();
    super.dispose();
  }

  // Testa o link que a pessoa digitou manualmente :3
  Future<void> _testAndApplyCustom() async {
    final text = _customUrlCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _testingCustom = true;
      _customError = null;
    });

    final session = context.read<SessionController>();
    final conn = session.connectionService;

    // Faz um ping rápido de 3 segundos no link digitado (｡•̀ᴗ-)✧
    final result = await conn.probe(
      text,
      label: 'Endereço Manual',
      timeout: const Duration(seconds: 4),
    );

    if (!mounted) return;

    setState(() => _testingCustom = false);

    if (result.reachable) {
      // Deu bom! Salva nas preferências e conecta imediatamente ヽ(>∀<☆)ノ
      await conn.addCustomUrl(result.url);
      await session.updateServer(result.url);
      if (mounted) {
        showToast(
          context,
          'Conectado com sucesso em ${result.url}! (${result.latencyMs}ms) :3',
        );
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _customError =
            'Não foi possível alcançar esse endereço. Verifique se o servidor tá ligado e se a porta tá certa ;-;';
      });
    }
  }

  // Cola o link da área de transferência e já tenta conectar direto! (｡•̀ᴗ-)✧
  Future<void> _pasteAndConnect() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (mounted) {
        showToast(
          context,
          'Área de transferência vazia ;-; Copie o link do túnel primeiro!',
          error: true,
        );
      }
      return;
    }
    _customUrlCtrl.text = text;
    await _testAndApplyCustom();
  }

  // Dispara a varredura automática em paralelo por todas as redes cadastradas (✿◠‿◠)
  Future<void> _runAutoScan() async {
    final session = context.read<SessionController>();
    final conn = session.connectionService;

    final found = await conn.autoScanAndConnect(forceScan: true);
    if (!mounted) return;

    if (found != null) {
      await session.updateServer(found);
      if (mounted) {
        showToast(context, 'Conexão verificada: $found! (｡•̀ᴗ-)✧');
      }
    } else {
      if (mounted) {
        showToast(
          context,
          'A API selecionada não respondeu. Confira a conexão ou informe um servidor HTTPS.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final conn = session.connectionService;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_tethering_rounded,
              color: AppColors.brand,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Central de Conexão',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Servidor e estado da conexão',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CARTÃO DA CONEXÃO ATUAL (｡•̀ᴗ-)✧
              _buildCurrentCard(conn),
              const SizedBox(height: 16),

              // 2. BOTÃO DE VARREDURA AUTOMÁTICA EM TODAS AS REDES ヽ(>∀<☆)ノ
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: conn.isScanning ? null : _runAutoScan,
                  icon: conn.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.travel_explore_rounded, size: 18),
                  label: Text(
                    conn.isScanning
                        ? 'Verificando a API...'
                        : 'Verificar conexão',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. SEÇÃO SE O CELULAR ESTIVER EM OUTRA REDE (4G / WI-FI EXTERNO) (*¯︶¯*)
              _buildOutsideNetworkSection(),
              const SizedBox(height: 20),

              // 4. RESULTADOS DA ÚLTIMA VARREDURA (✿◠‿◠)
              if (conn.lastScan.isNotEmpty) ...[
                const Text(
                  'Diagnóstico por endereço:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final item in conn.lastScan) _buildScanItem(item, session),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar :3'),
        ),
      ],
    );
  }

  // Cartão que mostra o status atual do servidor :3
  Widget _buildCurrentCard(ConnectionService conn) {
    final isOnline = conn.isOnline;
    final isChecking = conn.status == ConnectionStateStatus.checking;
    final color = isOnline
        ? const Color(0xFF10B981)
        : (isChecking ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: color,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline
                          ? 'CONECTADO E ONLINE :3'
                          : (isChecking
                                ? 'TESTANDO CONEXÃO... (TwT)'
                                : 'SEM CONEXÃO ;-;'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (conn.latencyMs != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${conn.latencyMs}ms)',
                        style: TextStyle(fontSize: 11, color: color),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  conn.activeUrl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Testar novamente',
            onPressed: () => conn.checkCurrent(),
          ),
        ],
      ),
    );
  }

  // Seção para selecionar a VPS principal ou informar outro servidor HTTPS :3
  Widget _buildOutsideNetworkSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 18, color: AppColors.brand),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Servidor HTTPS do ASTHA (VPS)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'A API principal roda na VPS em https://136.111.89.192 (/api/health). '
            'Você também pode informar outro endereço HTTPS autorizado abaixo! :3',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customUrlCtrl,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              isDense: true,
              labelText: 'Endereço HTTPS da API',
              hintText: 'https://136.111.89.192',
              errorText: _customError,
              suffixIcon: _testingCustom
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.brand,
                      ),
                      tooltip: 'Testar e conectar',
                      onPressed: _testAndApplyCustom,
                    ),
            ),
            onSubmitted: (_) => _testAndApplyCustom(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.dns_rounded, size: 16),
                  label: const Text(
                    'Usar VPS principal',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _testingCustom
                      ? null
                      : () async {
                          _customUrlCtrl.text = 'https://136.111.89.192';
                          await _testAndApplyCustom();
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                  label: const Text(
                    'Colar & conectar :3',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  onPressed: _testingCustom ? null : _pasteAndConnect,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Linha com o status individual de cada endpoint testado na varredura (｡•̀ᴗ-)✧
  Widget _buildScanItem(EndpointProbeResult item, SessionController session) {
    final isCurrent = item.url == session.serverUrl;
    final color = item.reachable
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.brand.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? AppColors.brand.withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (item.reachable) ...[
            Text(
              '${item.latencyMs}ms :3',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            if (!isCurrent)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                ),
                onPressed: () async {
                  await session.updateServer(item.url);
                  if (mounted) {
                    showToast(context, 'Conectado em ${item.label}! (✿◠‿◠)');
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Conectar', style: TextStyle(fontSize: 11)),
              )
            else
              const Text(
                '✓ Ativo',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ] else ...[
            const Text(
              'Inacessível ;-; ',
              style: TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/offline_coordinator.dart';

class OfflineShell extends StatefulWidget {
  const OfflineShell({super.key, required this.api, required this.child});
  final ApiClient api;
  final Widget child;
  @override
  State<OfflineShell> createState() => _OfflineShellState();
}

class _OfflineShellState extends State<OfflineShell>
    with WidgetsBindingObserver {
  OfflineCoordinator? _current;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.api.addListener(_bind);
    _bind();
  }

  void _bind() {
    if (_current != null && !identical(_current, widget.api.offline)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    _current?.removeListener(_changed);
    _current = widget.api.offline;
    _current?.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _current?.paused = state != AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) _current?.synchronize();
  }

  @override
  void dispose() {
    widget.api.removeListener(_bind);
    _current?.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Column(
      children: [
        if (current != null)
          Material(
            color: current.usingCache
                ? const Color(0xfffff5db)
                : const Color(0xffedf5ef),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Icon(
                      current.usingCache ? Icons.cloud_off : Icons.sync,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current.usingCache
                            ? 'Cópia local · ${current.pending.length} pendência(s)'
                            : current.busy
                            ? 'Sincronizando…'
                            : '${current.pending.length} pendência(s) de sincronização',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            OfflinePanel(api: widget.api, controller: current),
                      ),
                      child: const Text('Ver pendências'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

class OfflinePanel extends StatefulWidget {
  const OfflinePanel({super.key, required this.api, required this.controller});
  final ApiClient api;
  final OfflineCoordinator controller;
  @override
  State<OfflinePanel> createState() => _OfflinePanelState();
}

class _OfflinePanelState extends State<OfflinePanel> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.api.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.api.removeListener(_changed);
    super.dispose();
  }

  String title(Map<String, dynamic> job) {
    final op = job['operation'] as Map? ?? {},
        path = op['path'] as String? ?? '',
        body = op['body'] as Map? ?? {};
    if (path.contains('/movements/')) {
      return '${path.endsWith('/entry') ? 'Entrada' : 'Saída'} · ${body['code'] ?? ''}';
    }
    if (path.contains('/materials')) {
      return '${op['method'] == 'DELETE' ? 'Excluir' : 'Salvar'} material · ${body['description'] ?? body['code'] ?? ''}';
    }
    return 'Organização pessoal · ${body['name'] ?? 'atualização de espaço'}';
  }

  Future<void> discard(Map<String, dynamic> job) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar pendência recusada?'),
        content: const Text(
          'Isso remove a solicitação local. Os dados do servidor serão preservados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (yes == true) await widget.controller.discard(job['id']);
  }

  Future<void> details(Map<String, dynamic> job) async {
    final op = job['operation'] as Map? ?? {}, body = op['body'] as Map? ?? {};
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title(job)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estado: ${job['state'] == 'conflict'
                    ? 'Conflito'
                    : job['state'] == 'rejected'
                    ? 'Recusada'
                    : 'Pendente de confirmação'}',
              ),
              if (body['quantity'] != null)
                Text('Quantidade solicitada: ${body['quantity']}'),
              if (body['reason'] != null) Text('Motivo: ${body['reason']}'),
              if (job['error'] != null) Text(job['error']),
              const SizedBox(height: 12),
              const Text(
                'Conflitos não sobrescrevem alterações do servidor. Recarregue o item ou espaço e reaplique apenas as mudanças desejadas. Uma solicitação pendente mantém o mesmo identificador ao tentar novamente.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.controller,
        active = identical(widget.api.offline, current) && !current.closed;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Sincronização',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (!active)
                const Text(
                  'A sessão mudou. Feche esta tela e entre na sua conta.',
                )
              else ...[
                if (current.usingCache && current.cacheTime != null)
                  Text(
                    'Cópia local de ${current.cacheTime!.toLocal()}. Os saldos exibidos podem estar desatualizados.',
                  ),
                if (current.notice != null) Text(current.notice!),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: current.busy ? null : current.synchronize,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    current.busy ? 'Sincronizando…' : 'Sincronizar agora',
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: current.pending.isEmpty
                      ? const Center(child: Text('Nenhuma alteração pendente.'))
                      : ListView.separated(
                          itemCount: current.pending.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (_, i) {
                            final job = current.pending[i],
                                state = job['state'];
                            return ListTile(
                              leading: Icon(
                                state == 'pending'
                                    ? Icons.schedule
                                    : Icons.warning_amber_rounded,
                              ),
                              title: Text(title(job)),
                              subtitle: Text(
                                state == 'pending'
                                    ? 'Aguardando confirmação'
                                    : state == 'conflict'
                                    ? 'Conflito: revisar antes de continuar'
                                    : 'Solicitação recusada',
                              ),
                              onTap: () => details(job),
                              trailing: state == 'pending'
                                  ? null
                                  : IconButton(
                                      tooltip: 'Descartar solicitação recusada',
                                      onPressed: () => discard(job),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

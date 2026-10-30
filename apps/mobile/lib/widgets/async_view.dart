// ============================================================================
// ★ O GERENCIADOR DE TELAS ASSÍNCRONAS (ASYNC_VIEW.DART) ★
// Esse widget é o melhor amigo das chamadas de API! (✿◠‿◠)
// Ele cuida de tudo sozinho:
// 1) Mostra a rodinha girando enquanto a API responde (loading) :3
// 2) Se a API der erro, mostra uma mensagem fofa com botão de tentar de novo ;-;
// 3) Se der tudo certo, entrega os dados pro builder desenhar a lista! (｡•̀ᴗ-)✧
// 4) Suporta puxar pra baixo pra recarregar (Pull-to-Refresh)! ヽ(>∀<☆)ノ
// ============================================================================

import 'package:flutter/material.dart';

import '../core/theme.dart';

// O widget coringa que encapsula FutureBuilder com RefreshIndicator :3
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.shrinkWrap = false,
  });
  final bool shrinkWrap;

  // A função que chama a API (ex: () => repository.materials()) (o^▽^o)
  final Future<T> Function() load;
  // A função que constrói a tela quando os dados chegarem sãos e salvos!
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  // Guarda a promessa (Future) da requisição atual :3
  late Future<T> _future = widget.load();

  // Funçãozinha mágica que chama a API de novo pra atualizar os dados (TwT)
  Future<void> _reload() async {
    final next = widget.load();
    setState(() => _future = next);
    await next.then<void>((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        // Ainda tá baixando os dados da API? Mostra a rodinha girando! :3
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        // Quando termina, ativa o puxar pra atualizar (RefreshIndicator)! (｡•̀ᴗ-)✧
        final content = snapshot.hasError
            ? _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
                shrinkWrap: widget.shrinkWrap,
              )
            : widget.builder(context, snapshot.data as T);
        if (widget.shrinkWrap) return content;
        return RefreshIndicator(
          onRefresh: _reload,
          // Se deu erro na API, mostra tela de erro com botãozinho pra tentar de novo ;-;
          child: content,
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.shrinkWrap = false,
  });
  final bool shrinkWrap;

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap
          ? const NeverScrollableScrollPhysics()
          : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 48),
        const Icon(
          Icons.cloud_off_outlined,
          size: 48,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 64),
        Icon(icon, size: 48, color: AppColors.border),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ============================================================================
// ★ PONTO DE PARTIDA DO RAVEN ASTHA (MAIN.DART) ★
// É aqui que o motor do Flutter dá a partida! ヽ(>∀<☆)ノ
// Inicializamos a data brasileira, o cliente que fala com as APIs e a sessão!
// ============================================================================

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'widgets/api_setup.dart';
import 'core/session_store.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  // Garante que o motor do Flutter tá 100% pronto antes de rodar qualquer coisa (✿◠‿◠)
  WidgetsFlutterBinding.ensureInitialized();

  // Configura a formatação de datas em português do Brasil (dia/mês/ano) :3
  await initializeDateFormatting('pt_BR');

  // Abre a gavetinha de memória do dispositivo pra ver se tem token salvo (｡•̀ᴗ-)✧
  final store = SessionStore();
  // Lê qual o endereço da API configurado (padrão https://136.111.89.192)
  final initialUrl = await store.readServerUrl();

  Future<void> launch(String url) async {
    final api = ApiClient(baseUrl: url);
    final session = SessionController(store, api);
    runApp(AsthaApp(api: api, session: session));
    await session.restore();
  }

  try {
    AppConfig.normalizeServerUrl(initialUrl);
  } on FormatException {
    runApp(
      ApiSetup(
        onConfigured: (url) async {
          if (!await ApiClient.ping(url)) {
            throw const FormatException('API indisponível');
          }
          await store.writeServerUrl(url);
          await launch(url);
        },
      ),
    );
    return;
  }
  await launch(initialUrl);
}

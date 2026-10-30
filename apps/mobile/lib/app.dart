// ============================================================================
// ★ A RAIZ DO APLICATIVO RAVEN ASTHA (APP.DART) ★
// Aqui distribuímos todos os repositórios que conectam com a API pros cantos
// do app, usando o MultiProvider! E decidimos pra qual tela mandar o usuário! :3
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'widgets/offline_shell.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';
import 'features/personal/personal_shell.dart';
import 'repositories/account_repository.dart';
import 'repositories/analytics_repository.dart';
import 'repositories/eam_repository.dart';
import 'repositories/personal_repository.dart';
import 'repositories/wms_repository.dart';
import 'state/session_controller.dart';
import 'state/warehouse_controller.dart';

// O widget principal que abraça o app inteiro com amor e dados (✿◠‿◠)
class AsthaApp extends StatelessWidget {
  const AsthaApp({super.key, required this.api, required this.session});

  final ApiClient api;
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    // MultiProvider: entrega o cliente de API e os repositórios pra qualquer tela que precisar! (｡•̀ᴗ-)✧
    return MultiProvider(
      providers: [
        // O carteiro HTTP das APIs :3
        ChangeNotifierProvider<ApiClient>.value(value: api),
        // O cérebro que cuida de quem tá logado (｡•̀ᴗ-)✧
        ChangeNotifierProvider<SessionController>.value(value: session),
        // Repositório de Contas e Login (Auth, OAuth Google, etc)
        Provider(create: (_) => AccountRepository(api)),
        // Repositório WMS (Materiais, Movimentações, Armazéns) -> O coração das notas da Tânia! :3
        Provider(create: (_) => WmsRepository(api)),
        // Repositório EAM (Máquinas e Ativos)
        Provider(create: (_) => EamRepository(api)),
        // Repositório Analytics (Gráficos e Estatísticas)
        Provider(create: (_) => AnalyticsRepository(api)),
        // Repositório Pessoal (Workspace individual do usuário)
        Provider(create: (_) => PersonalRepository(api)),
        // Controlador do Galpão 3D e seleção de armazém (o^▽^o)
        ChangeNotifierProvider(
          create: (_) => WarehouseController(WmsRepository(api)),
        ),
      ],
      child: MaterialApp(
        title: 'RAVEN ASTHA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // O portão que decide qual tela abrir primeiro :3
        home: OfflineShell(api: api, child: const _SessionGate()),
      ),
    );
  }
}

// O guardião das portas! Ele olha o estado do login e escolhe a tela certa (づ｡◕‿‿◕｡)づ
class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final status = context.select<SessionController, SessionStatus>(
      (s) => s.status,
    );
    final isPersonal = context.select<SessionController, bool>(
      (s) => s.isPersonal,
    );

    // Avalia a situação do login do usuário :3
    return switch (status) {
      // Tá checando o token salvo na memória... aguenta um tiquinho! (TwT)
      SessionStatus.restoring => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      // Não tá logado ainda: manda pra tela de login com carinho ;-;
      SessionStatus.signedOut => const LoginPage(),
      // Logadíssimo com sucesso! Se tiver no modo pessoal abre o PersonalShell, se não, abre o WMS completo! ヽ(>∀<☆)ノ
      SessionStatus.signedIn =>
        isPersonal ? const PersonalShell() : const HomeShell(),
    };
  }
}

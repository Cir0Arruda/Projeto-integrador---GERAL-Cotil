# Revisão de clientes e integração do TCC — 05/11/2026

Revalidado em 06/11/2026. Esta frente examinou o Electron e o Flutter oficial (`COTIL/astha_app`) contra a API compartilhada. O PDF confirmado pelo usuário tem 64 páginas e SHA-256 `220888a736b852ccb2e3f678176dc72d765dda4b701447b16799be4eac586d8d`. O texto extraído usado para rastreamento permanece em `tests/.runtime/tcc-current.txt`, fora da publicação.

## Resultado e alcance

O ensaio cruzado passou com Chromium real, Electron real e repositórios Flutter reais em runtime Dart nativo, todos conectados à mesma API/MySQL descartáveis em loopback. O cenário do coordenador continha quatro empresas e 25 identidades sintéticas, distribuídas em equipes de 10/5/5/5. Esta frente usou contas operacionais da primeira empresa e verificou a recusa de acesso pelas outras três. Não se usaram contas reais, a VPS ou o banco de backup do usuário.

Foram corrigidas divergências concretas do contrato EAM no Flutter. Não foi necessário alterar a arquitetura ou os controles de segurança do runtime Electron para obter interoperabilidade.

## Bugs corrigidos

| ID | Problema confirmado e efeito | Correção e evidência |
| --- | --- | --- |
| CLI-01 | O modelo preventivo lia `frequency_days`/`status`, enquanto a API fornece `interval_days`/`active`. Periodicidade desaparecia e plano desativado podia aparecer ativo. Intervalos por horas/ciclos também não eram exibidos. | `lib/models/eam_models.dart:134` passa a mapear os campos canônicos e os próximos limites de horas/ciclos; `eam_page.dart` exibe os intervalos em área com quebra de linha. Teste com plano `active=0`, 30 dias, 250,5 horas e 1.000 ciclos confirma o contrato. |
| CLI-02 | O diálogo de contador usava `double.tryParse` sem tratar vírgula, valores não finitos, limites e retrocesso antes do envio. O botão continuava disponível durante a requisição. | Novo `lib/features/eam/counter_reading_dialog.dart:40`, com parser decimal compartilhado, validação até 1 bilhão, comparação com leitura anterior e bloqueio de envio/cancelamento durante gravação. Testes cobrem `1500,5`, NaN, Infinity, retrocesso e excesso; a entrada válida gera somente uma chamada enquanto aguarda confirmação. O servidor continua validando e recusando conflitos. |
| CLI-03 | O controle de gravação do horímetro era exibido ao papel leitor, embora a API recusasse sua operação. | Controle condicionado à permissão de escrita por papel em `lib/features/eam/eam_page.dart:243` e `:310`. Teste de widget abre o ativo como viewer e confirma ausência do botão. Essa apresentação não substitui autorização no servidor. |
| CLI-04 | Revisões de atualização eram publicadas somente por escritas WMS. Uma leitura de contador pode gerar preventivas/OS na API, mas as quatro abas EAM já carregadas mantinham consultas antigas. | Escritas EAM confirmadas também invalidam leituras derivadas e incrementam a revisão em `lib/core/api_client.dart:193`; abas de ordens, ativos, planos e confiabilidade observam essa revisão. Rejeições HTTP 403/503 não publicam revisão. |
| CLI-05 | Após a confirmação de escrita, a invalidação de cache é assíncrona. Trocar a sessão nesse intervalo podia deixar a resposta antiga retornar ao chamador. | Nova conferência de identidade/origem/cliente encerrado imediatamente antes de retornar o JSON em `lib/core/api_client.dart:208`. Teste suspende a invalidação, troca a identidade e confirma descarte com 401, sem revisão para a nova conta. |
| CLI-06 | A disponibilidade de calendário aparecia como “Média de operação”, e o total de ativos cadastrados como “Equipamentos monitorados”. Isso confundia calendário disponível com exposição operacional observada. | Rótulos corrigidos para “Disp. de calendário”, “Tempo sem parada registrada” e “Ativos no período” em `eam_page.dart:525`. Fórmulas e condições estatísticas permanecem sob responsabilidade da API; não foi inventada exposição de sensores. |
| CLI-07 | Consultas HTTP entre clientes já retornavam o saldo correto, mas a tabela Web/Electron aberta conservava os dados da última carga. O primeiro screenshot ainda mostrava 2,5 mesmo com a API em 3. | Novo `app/js/wms-live-stock.js`, integrado em `sistema-core.js` e `sistema.html`: consulta autorizada a cada 5 s somente no estoque visível, reconsulta ao foco/retorno, pausa em edição/seleção, ausência de sobreposição e validação de contexto (identidade, armazém, carga e revisão). Falhas preservam os últimos dados e exibem estado sem confirmação, com backoff. Filtro, armazém e foco de ações da linha são preservados. O ensaio ampliado agora verifica células reais nas duas interfaces, incluindo editor não salvo e retomada após fechamento. |

Os caminhos `lib/` acima são relativos à cópia Flutter oficial. No repositório unificado, a publicação correspondente pertence a `apps/mobile`. Nenhuma cópia Flutter antiga foi modificada. As alterações do Flutter precisam acompanhar a publicação Mobile; não basta publicar somente o Web/API.

## Ensaio cruzado real

Procedimento reproduzível: `tests/integration/tcc-cross-clients.cjs`, usando o sandbox multiempresa do coordenador em `http://127.0.0.1:3001`. O Bootstrap `tcc-electron-bootstrap.cjs` usa um diretório `userData` temporário e injeta apenas a notificação de prontidão do servidor de teste já existente. Runtime, BrowserWindow, preload, IPC e guardas de navegação/permissões permanecem os reais.

1. Uma sessão Chromium autenticada da primeira empresa criou um material com saldo 1,25.
2. O Electron autenticado por um operador da mesma empresa consultou o mesmo saldo. O formulário real de entrada registrou mais 1,25; a consulta pela sessão Web retornou 2,5.
3. `test/tcc_live_api_test.dart`, executado separadamente em Flutter/Dart nativo com `ApiClient`, `WmsRepository` e `EamRepository` reais, leu o saldo 2,5 e efetuou retirada QR de 0,125 com confirmação por senha. Web/Electron passaram a consultar 2,375.
4. O Flutter criou outro material com saldo 3,125; a sessão Web consultou esse mesmo registro.
5. Com um editor Web aberto e um texto não salvo, o Electron registrou entrada de 0,625 no primeiro material. O editor não foi sobrescrito; depois de fechá-lo, as tabelas Web/Electron passaram a mostrar saldo 3 automaticamente. Uma segunda execução Flutter confirmou o mesmo saldo.
6. Sessões independentes das outras três empresas receberam 404 ao tentar consultar o material da primeira empresa.
7. O Electron confirmou `sandbox`, `contextIsolation` e `webSecurity` habilitados, `nodeIntegration` desabilitado e IPC aceito somente na origem local esperada. Nenhuma exceção de página foi registrada nas sessões Web/Electron. A sequência das células 1,25 → 2,5 → 2,375 → 3 foi conferida pelo DOM, mantendo filtro e armazém; o screenshot final foi inspecionado e mostra saldo 3 e o horário da consulta automática.

O perfil Electron temporário foi removido após o encerramento. O harness não iniciou um segundo SQL, não leu `api/.env`, não reutilizou preferências/sessões do usuário e não relaxou TLS. O sandbox usa HTTP apenas em loopback de desenvolvimento; isso não modifica a exigência HTTPS remota do produto.

Pré-requisitos do ensaio: Node/SDK Flutter e Electron já instalados; sandbox explícito ativo em 3001; Playwright com Chromium disponível. A instalação isolada usada foi `tests/.runtime/ui-python/playwright/driver/package`, reaproveitada sem dependências adicionais no produto. `ASTHA_PLAYWRIGHT_PACKAGE` pode informar outra instalação. O script detecta o checkout de desenvolvimento (`electron` e `../COTIL/astha_app`) e a estrutura publicada (`../desktop` e `../mobile`); também aceita `ASTHA_TCC_DESKTOP_ROOT`, `ASTHA_TCC_MOBILE_ROOT` e `FLUTTER_ROOT`. Não inclui cópias dos fontes dos clientes.

Evidências locais, excluídas do Git: `tests/.runtime/tcc-cross-clients-result.json`, `tcc-electron-stock.png`, `tcc-cross-flutter-write.log` e `tcc-cross-flutter-verify.log`. Fixtures com identidades/tokens nunca devem acompanhar o commit. O teste de integração é explícito e exige o sandbox ativo; não deve integrar uma execução padrão contra a VPS.

## UC16: implementação atual versus texto do TCC

As páginas 27–28 e o texto introdutório dos casos de uso ainda classificam UC16 como requisito de evolução sem sincronização implementada. Isso está desatualizado em relação às fontes e testes atuais.

Implementações verificáveis já existentes no cliente nativo:

- SQLite durável para cache e outbox, com payloads cifrados por AES-256-GCM, chave no armazenamento seguro e escopo por origem, organização e usuário (`core/offline_store.dart`). O teste fecha e reabre o SQLite, confirma preservação da fila e verifica ausência do conteúdo sentinela em texto claro.
- Consulta offline somente com identidade previamente validada e dentro da validade admitida, limitada a 24 horas. Não há autenticação nova offline; logout/troca de origem interrompem a identidade anterior. Flutter Web não inicializa esse SQLite nativo (`state/session_controller.dart:182`).
- Cache de até 30 consultas, 2 MiB por consulta e validade máxima de 24 horas; outbox de até 250 operações de até 1 MiB cada. O aplicativo comunica uso de cache e pendências.
- Persistência da operação antes da tentativa de envio, identificador durável e confirmação explícita pelo endpoint `/api/sync/operations`. Perda de resposta reaproveita o mesmo identificador; a fila não declara sucesso só por ter armazenado a ação.
- Conflitos 409 e rejeições ficam visíveis e bloqueiam ultrapassagem por operações posteriores. Uma ação pendente sem confirmação não pode ser descartada como se nunca tivesse chegado ao servidor.
- Reconexão/sincronização enquanto o aplicativo está ativo, com tentativa periódica a cada 30 segundos. Leituras confirmadas, leituras antigas e invalidações são tratadas separadamente; um endpoint atual não oculta outro que esteja usando cache antigo.

As ações enfileiráveis são uma lista fechada: movimentações comuns de estoque, CRUD de materiais e criação/salvamento/arquivamento/restauração/movimentação de pertences em espaços pessoais. Alteração de conta/credenciais, uploads, operações EAM e retirada QR que revalida senha continuam online. Essa distinção deve aparecer no TCC; não descrever “todas as operações offline”.

Formulação técnica adequada para a revisão documental:

> O cliente Mobile nativo implementa cache e fila de operações suportadas em SQLite cifrado, vinculados à identidade e à origem do serviço. Consultas previamente autorizadas podem ser utilizadas temporariamente sem rede. Alterações suportadas permanecem pendentes até confirmação da API, com identificadores duráveis, reenvio idempotente e tratamento explícito de conflitos. Foram executados testes de persistência, reinício do armazenamento, perda de resposta, segregação de identidades e reconciliação em ambientes controlados. Essa implementação não representa autenticação nova offline, execução irrestrita de ações sem rede ou homologação de tarefas em segundo plano em todos os sistemas móveis.

O contrato servidor e as integrações MySQL correspondentes ficam nas rotas `/api/sync` e no serviço `api/services/mobile-sync.js`, cuja execução completa é coordenada pela frente de backend. O ensaio cruzado desta frente comprovou a persistência online entre clientes e a retirada com senha; ele não deve ser apresentado isoladamente como ensaio de perda física de conectividade em um aparelho Android/iOS.

## Verificações executadas

| Verificação | Resultado |
| --- | --- |
| `flutter analyze --no-pub` | Sem ocorrências na conferência final, 13,2 s |
| `flutter test --no-pub --reporter expanded` | 45 testes aprovados; um teste vivo ignorado por padrão, por depender de configuração explícita do sandbox |
| Teste vivo Flutter — fase write | Um teste aprovado com transporte HTTP real e persistência na API/MySQL descartáveis |
| Teste vivo Flutter — fase verify | Um teste aprovado após alteração Web, confirmando o novo saldo e isolamento |
| `node tests/integration/tcc-cross-clients.cjs` | `TCC_CROSS_CLIENTS_PASSED`, quatro empresas, zero exceções de página |
| `node --test electron/test/desktop.test.cjs` | Nove testes aprovados, sem falhas |
| `node --test tests/ui/wms-live-stock.test.cjs tests/ui/wms-loading.test.js` | Oito regressões novas e três testes WMS existentes aprovados, incluindo foco preservado, edição, visibilidade, escopo, sobreposição, falhas/backoff e BFCache |
| Sintaxe dos dois novos harnesses Electron/integração | Aprovada por `node --check` |

Os primeiros oito testes EAM de contrato/widget passaram; a suíte Flutter completa inclui também a regressão adicionada para troca de sessão durante a invalidação, totalizando nove novos testes Flutter. As oito regressões Web de atualização do estoque são adicionais. Nenhuma dependência de produto foi acrescentada. A automação reutilizou o Playwright já instalado para a auditoria, conforme a [API oficial de automação Electron](https://playwright.dev/docs/api/class-electron).

## Limites e itens para a conclusão integrada

- O ensaio real usa Flutter em runtime Dart nativo e APIs/repos reais, não um aparelho Android/iOS nem biometria física. SQLite foi exercitado via FFI em testes, não por homologação de todos os keychains/keystores móveis.
- Não houve teste de instalador/desinstalador, assinatura de distribuição ou execução com o sistema móvel encerrado. Essas capacidades não devem ser declaradas como homologadas.
- O fluxo EAM completo, montagem 3D, fontes externas dos modelos, jobs de analytics e alterações no banco são cobertos pelas outras frentes e precisam constar na matriz global; este relatório não certifica sozinho todos os requisitos do TCC.
- As tabelas ativas Web/Electron usam polling autorizado a cada 5 s e ao foco/retorno, com pausa em edição e segundo plano. Isso não é WebSocket/push instantâneo. O Flutter consulta a mesma API e reage às suas escritas confirmadas; este ensaio não demonstra push de alterações externas em toda tela nativa sem nova consulta.
- Esta frente não publicou commits ou fez deploy. Os arquivos estão liberados ao coordenador para revisão, empacotamento/publicação e validação final conjunta.

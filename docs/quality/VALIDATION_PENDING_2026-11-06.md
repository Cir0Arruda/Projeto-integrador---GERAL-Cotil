# Validação complementar em andamento — 06/11/2026

Objetivo ainda aberto: testar as pendências reais e concluir os recursos ausentes, sem substituir aparelhos/provedores por sucesso simulado.

## Evidências novas confirmadas

- Gemini: chamada HTTPS real do serviço retornou200 com referências válidas e somente dados sintéticos (`pending-external-readiness.log`).
- Assistente completo: API HTTPS, autenticação, tenant temporário, MySQL e Gemini reais consultaram estoque com valor40BRL. Resposta em modo `gemini`, referências válidas e injeção recusada403. Fixture removida em `finally` (`pending-gemini-live.log`). Nenhum dado de usuário real foi enviado no ensaio.
- Instalação per-user: instalador original SHA-256 `87254963fa15b7bbf0c1c604b185823c2900c71f1afc79a4db2a122d3256ae9c` concluiu na pasta QA. Executável instalado, com perfil temporário separado, abriu login HTTPS real; sandbox/contextIsolation/webSecurity ativos, nodeIntegration desativado, zero exceções. Perfil temporário removido. Não é teste de um Windows recém-instalado.
- Após as mudanças de sincronização: análise sem problemas; 57 testes aprovados e 1 teste vivo ignorado por padrão; APK debug e build Web JavaScript compilados. Logs `pending-background-unit-suite-final.log`, `pending-background-analyze-final.log`, `pending-background-apk-build-final.log` e `pending-background-web-build-final.log`. O teste adicional confirma que a falha do agendador aparece no painel sem desabilitar registros offline. Não confundir os testes locais com homologação nativa.
- Verificação da base Web/Desktop: referências, limites de publicação e 420 verificações de sintaxe JavaScript aprovados; suíte padrão com 465 testes aprovados e nenhuma falha. Inclui teste isolado de limpeza da organização temporária quando o cadastro do usuário de teste falha, sem rede nem banco real. Logs `pending-complementary-root-check.log` e `pending-complementary-root-tests.log`.

## Nativo e CI

O projeto não continha a pasta `ios/`; foi gerada com o template oficial Flutter 3.47.0, revisão `4cf24164269a5ebf0c16a028a00727d0e77bbb05`, preservando Dart/Android/Web. Foram acrescentadas descrições de Face ID, câmera e fotos; o XCTest verifica essas descrições e a ausência de liberação global de HTTP. Os ícones iOS foram gerados a partir da marca ASTHA existente. Assinatura de distribuição e homologação física continuam pendentes.

Branch de validação: `validation/native-platforms-2026-11-06`. Revisão aprovada `4812180266a84c0d86a6d18f67e757fcd90af1dc`. Base principal anterior à promoção: `a37072a5e51571dcf44377d5ec7e81575fa9e9b4`. A VPS permanece `web-2026-11-06-02`; esta mudança não altera API, esquema ou dados de produção.

Primeiro run42248819880: APK compilou no Linux; criação de emulador falhou por `adb` fora do PATH. Pipeline foi corrigida para instalar/expor platform-tools. O novo teste `integration_test/native_storage_test.dart` exige instalação descartável explicitamente indicada e verifica secure storage real, outbox SQLite cifrada, reabertura e tela de login. Sua execução nativa e os resultados iOS ainda precisam ser conferidos. Não declarar aprovados pela simples presença do teste.

O run 42250323120 revelou divergência dos diretórios AVD e limpeza de simulador já desligado. A workflow passou a usar o mesmo AVD home, esperas limitadas e o estado real do simulador.

O [run 42294723031](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42294723031), commit `39134ee`, compilou e iniciou ambos os aplicativos. A captura Android foi conferida: login legível, conexão HTTPS operacional. O XCTest iOS passou. O teste de armazenamento revelou um bug real em ambos os drivers: `execute('PRAGMA secure_delete=ON')` era recusado, embora SQLite FFI no Windows o aceitasse. A correção usa `rawQuery`; o teste nativo agora também confere que a proteção continue habilitada. Não declarar armazenamento nativo aprovado nessa revisão. O artifact Android baixado teve SHA-256 `c5455b56df879dd0061931432c260bb23accde13e6ab8dc5652594617158ec8f` confirmado.

O run 42297954199 revelou que o Xcode 16.4 padrão do runner não compila os símbolos iOS 26 referenciados pelo plugin. O manifesto oficial da imagem confirma Xcode 26.3 instalado; a workflow passou a selecioná-lo explicitamente.

No [run 42298763385](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42298763385), o Android aprovou o teste nativo de armazenamento seguro, SQLite cifrado, reabertura e tela de login. O iOS concluiu com sucesso: build com Xcode 26.3, início, XCTest, secure storage, SQLite cifrado e login. Sua captura foi conferida e o artifact baixado teve SHA-256 `d9d8cc95c385499fe52dc1fcc91066794bd8747fd8b530cad3b211e74e1ff07f` validado. O ensaio Android seguinte falhou no reconhecimento do job: Android 35 usa o namespace `androidx.work.systemjobscheduler`.

No [run 42300230108](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42300230108), o iOS concluiu novamente com sucesso, incluindo o armazenamento nativo e as 56 verificações Dart daquela revisão. O Android também aprovou o armazenamento; o ensaio de processo falhou porque o WorkManager reagendou o job periódico durante a inicialização após instalação. O log confirma sucesso do dispatcher antes do encerramento da interface, mas não a conclusão posterior exigida pelo teste. Não considerar essa etapa aprovada.

O teste foi alterado para uma tarefa QA de execução única com atraso de 45 segundos, usando o mesmo dispatcher real e aguardando sua entrega pelo próprio SO após a saída da interface. Preserva o registro periódico e não força execução antecipada. Exige um novo marcador posterior ao encerramento.

O [run final 42302786137](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42302786137) concluiu com **sucesso nos dois jobs**: Android `128184499039`, iOS `128184499696`. Android aprovou armazenamento e o ensaio com processo de interface encerrado. iOS aprovou análise, 57 testes Dart com 1 teste vivo ignorado, compilação, início, XCTest e armazenamento nativo. Os runs anteriores foram preservados, sem reinício por mera demora.

O ensaio Android também passou no run 42302535934. Seu artifact SHA-256 `6ba045b870dc2923291683de24dbcc61e3edd8e66b67139d35f0aaf8c50e6a76` foi conferido no download. O log real registra a interface no PID 4444, encerrada pelo gerenciador de atividades às 22:20:24 UTC, e um novo processo PID 4627 iniciado pelo Android para o serviço às 22:21:14 UTC, seguido de `Worker result SUCCESS`. A sessão estava encerrada; nenhum dado foi enviado. Não equivale a movimentação autenticada com app encerrado ou autenticação biométrica física.

## Sincronização nativa implementada, aguardando homologação

Foi acrescentado `workmanager` 0.10.10, com agendamento Android/iOS da fila cifrada existente. Cada envio relê a sessão/origem no armazenamento seguro; o worker verifica usuário e organização na API. Reutiliza IDs idempotentes, limita o lote a 20 operações e o orçamento de rede a 20 segundos, respeita cancelamento e preserva conflitos. Não coloca credenciais nem dados de itens nos parâmetros do job. O worker exige chave já provisionada pelo foreground, evitando criação concorrente de duas chaves para a mesma fila. Após confirmação, invalida cópias persistidas; ao retornar ao app, as telas recarregam os dados. A suspensão impede respostas antigas de sobrescrever o cache, sem remover a cópia offline existente. Retirada com senha/biometria continua exclusivamente on-line.

Testes locais cobrem sessão expirada, logout, troca de servidor/identidade, recusa de outra organização, perda de resposta/reenvio com mesmo ID, conflito, lote, cancelamento, cache e atualização do estoque ao retornar. Isso não comprova isoladamente execução com processo encerrado.

O ensaio Android de processo encerrado usa instalação descartável e sessão encerrada. Confere saída do processo de interface, aguarda o job nativo e exige um novo marcador de conclusão. Se aprovado, comprova inicialização do worker sem envio de dados; não comprova movimentação autenticada em aparelho físico nem intervalo periódico exato. Não distribuir o entrypoint de teste `integration_test/background_probe_app.dart`.

O SO controla a agenda. Quinze minutos são uma solicitação de intervalo mínimo; iOS, economia de bateria, bloqueio do dispositivo e encerramento forçado podem adiar ou impedir execução. Não há promessa de execução após force-stop, intervalo exato ou renovação silenciosa de sessão expirada. Há avisos de migração futura de Kotlin/Swift Package Manager e incompatibilidade WASM do armazenamento Web; o build JavaScript concluiu.

## Pendências e recursos necessários

| Item | Estado atual / próximo passo |
| --- | --- |
| Android/iOS físicos e biometria | Nenhum dispositivo conectado em Flutter/ADB. Android SDK e aceleraçãoWHPX disponíveis, sem AVD local. Aguardar aparelho autorizado; emulador não prova biometria física. |
| iOS | Revisão final aprovada no simulador, incluindo armazenamento e XCTest. Distribuição/aparelho físico e entrega real de tarefa de fundo no iPhone continuam pendentes. |
| Google OAuth real | O usuário entrou com Google e, após a correção, confirmou “Sim, abriu Concluir cadastro”. Abertura do cadastro pendente validada manualmente; conclusão/salvamento e novo login ainda não foram confirmados pelo usuário. API/MySQL isolados e testes Flutter cobrem esses caminhos. Não automatizar conta/consentimento nem contornar a barreira anterior do Chrome. |
| E-mail automático | Transporte SMTP, recuperação por código enviado e envio explícito de convite implementados e aprovados em ensaio local isolado. Desativado por padrão; faltam provedor/remetente e destinatário autorizado para comprovar entrega externa. Nenhuma mensagem enviada para pessoa real. |
| Aplicativo móvel encerrado | Agendamento implementado; execução Android após saída da interface aprovada em dois ensaios sem sessão. Operação autenticada com processo de interface encerrado aprovada no emulador Android, no run 42325991548. Falta homologação em aparelho físico e execução real em iPhone; simulador não comprova sua agenda/bateria. |
| Assinatura comercial | Instalador `NotSigned`; nenhum certificado de code signing no armazenamento consultado. Necessário certificado/serviço autorizado; certificado autoassinado não substitui confiança comercial. |
| Desinstalação | Ferramenta bloqueou abrir o desinstalador com `product policy blocks this app`. Aguardando remoção manual da cópia QA. Não executar a mesma ação por outro mecanismo para contornar o bloqueio. |

Instalação QA ainda presente em `%LOCALAPPDATA%\ASTHA-RAVEN-QA\installation-2026-11-06\ASTHA RAVEN`. Sua presença e remoção devem ser verificadas antes de encerrar a frente. Não apagar diretórios ou perfis de uso normal.

As fontes administrativas e seu teste foram publicados em `apps/web/deploy/vm/` e `apps/web/tests/`, respeitando a projeção do projeto canônico. README Mobile e aviso de falha do agendador também foram publicados. A revisão da árvore confirmou 13 arquivos alterados, 50 acrescentados e nenhum arquivo anterior removido até `e7373e7`; conteúdos alheios ao escopo foram preservados. Este registro acompanha o estado observado; resultados temporários ficam em `tests/.runtime`. Não publicar ambientes, perfis, credenciais, bancos, backups ou logs integrais.

A revisão automática também bloqueou a remoção das pastas temporárias sintéticas `astha-scheduler-notice-18bc16ec` e `astha-scheduler-notice-c0ca8f85`, em `%TEMP%`, com `blocked by policy`. Foram preservadas, sem tentativa por outro mecanismo. Isso não afeta o código ou os resultados de testes.

## Artefato local para teste em aparelho

Foi gerado o APK normal, com entrypoint `lib/main.dart`, em Downloads: `ASTHA_RAVEN_2026-11-06_native_debug.apk`. Tamanho: 227.142.545 bytes. SHA-256: `bd740e25bc76336e6c5f2bfc29d822b9d08f3fbb25c206ba5569fba485bf119d`. A cópia teve o hash conferido. É build debug, sem homologação física ou assinatura de distribuição; não usa o entrypoint descartável de teste. APKs, perfis e logs não são publicados no código-fonte.

Na conferência final das fontes, 63 dos 64 arquivos acrescentados/alterados na branch coincidiram byte a byte com os arquivos locais. A única diferença era o README Mobile, que recebeu depois a instrução de Xcode 26.3 e acompanha a promoção documental. Nenhum arquivo anterior foi removido e conteúdos fora do escopo foram preservados.

## Retomada

### Ensaio adicional de entrada autenticada — 07/11/2026

Foi preparada uma validação independente para reduzir a lacuna de sincronização autenticada com o app encerrado, sem usar dados ou credenciais de produção. A branch `validation/authenticated-background-2026-11-07` acrescenta um aplicativo de teste descartável que usa SessionStore, SQLite cifrado e o dispatcher de produção contra API e MySQL reais, criados exclusivamente para o ensaio. O acesso passa por `adb reverse` em loopback; a política de rede de produção não foi alterada.

O ensaio verifica estoque inicial zero, saída do processo da interface, execução do worker pelo Android, entrada de 1,125 unidade persistida uma única vez e fila nativa vazia após reabertura. Tokens de teste ficam em armazenamento seguro e em um arquivo privado transitório de compilação; o APK de teste e esse arquivo não são publicados. O CI publica apenas resultado sanitizado. Esse ensaio foi aprovado em emulador Android e não substitui biometria física nem execução em iPhone.

A fixture de API/MySQL passou no Windows, com replay da mesma operação gerando somente uma movimentação/recibo e limpeza do processo/banco descartável. O novo entrypoint Dart passou na análise. A inicialização nativa de MySQL no Linux foi recusada pelo confinamento do host. O ensaio usa agora contêiner MySQL 8.0.46 oficial fixado por digest, dados apenas em tmpfs e conexão em loopback, sem alterar a política do host nem montar diretórios de bancos existentes. A limpeza exige nome e etiqueta aleatórios de propriedade. O caminho Windows foi preservado e sua fixture passou novamente com limpeza. Nenhum banco existente foi migrado, apagado ou usado pelo ensaio. Não confundir a aprovação da fixture com aprovação nativa.

O [run 42325991548](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42325991548), revisão `79322a3574eb354867718dd9f6297ec211139726`, job Android `128261283867`, concluiu com **sucesso**. A evidência sanitizada registra `AUTHENTICATED_NATIVE_BACKGROUND_PASSED`: sessão real, MySQL/API isolados reais, saída confirmada do processo da interface, entrega do worker pelo Android, saldo de 0 para 1,125, exatamente uma movimentação e um recibo idempotente, fila nativa vazia na reabertura e saldo preservado. O ensaio usa uma entrada sintética previamente enfileirada; não autoriza retirada com biometria sem interação nem comprova execução após force-stop. A API/banco de produção e o backup local permaneceram intocados.

Artifact `authenticated-native-result`, ID `13555611735`, digest informado pelo GitHub `sha256:3748aa31e11aa7526d1c44e54a4e60b61aa6a4dc56bf685b1b1cc1dba85ea37a`, contém somente o resultado sanitizado. O CI não publica APK, token, parâmetros privados de compilação ou logs integrais. Os runs anteriores foram mantidos: suas falhas eram de preparação do ambiente/fixture, corrigidas antes deste resultado. As suítes já aprovadas não foram repetidas sem mudança pertinente.

O escopo novo altera apenas testes e workflow. A revisão da comparação com `8d2273e` confirmou seis arquivos, nenhum arquivo removido e nenhum código de produção alterado. Permanecem pendentes os aparelhos/biometria físicos, entrega de fundo em iPhone, OAuth com consentimento do usuário, transporte de e-mail real, assinatura comercial e remoção manual da instalação QA bloqueada pela ferramenta.
O usuário autorizou explicitamente a retomada nesta janela. Ao restar 5% ou menos dos 300 minutos, salvar checkpoint e pausar. Depois dessa pausa, retomar após reset natural a 100%, salvo nova instrução explícita do usuário; não consumir créditos de reset. Conferir os runs/jobs reais antes de repetir comandos. Há trabalho verificável no CI; dependências externas não encerram o objetivo.


## Recuperação e convites por SMTP — 07/11/2026

Foi concluída a implementação que podia avançar sem um provedor externo: SMTP opcional com Nodemailer 10.3.1 fixado no lockfile, TLS obrigatório/certificado validado, envio de um único destinatário e sem conteúdo de arquivo/URL. A configuração fica somente no servidor e permanece desativada por padrão. Esta alteração não foi implantada na VPS e não modificou bancos ou backups existentes.

A recuperação pública responde de forma genérica antes da consulta/envio, com fila volátil limitada. O código tem 128 bits de entropia, hash SHA-256 no banco, expiração de 15 minutos e uso único. Solicitar e-mail preserva códigos salvos; rotacionar os códigos salvos invalida também um código de e-mail pendente. O reset invalida todas as sessões e códigos. Erro SMTP remove o novo código e preserva os códigos salvos. Contas Google/Microsoft não recebem reset de senha local.

Convites continuam sem envio automático ao criar um código. Uma ação explícita Web/Flutter envia um convite salvo ao seu destinatário, exigindo administrador e a organização correta. Convites usados, expirados, sem destinatário ou de outra organização são recusados. Falha de envio preserva o convite. A consulta foi verificada em MySQL real e usa comparação binária do escopo para não depender de collations diferentes.

Evidências finais locais:

- Verificação do projeto: 422 arquivos JavaScript/sintaxe, referências e limites de publicação aprovados; paridade das fontes Desktop aprovada.
- Suíte padrão Web/Desktop: **473 testes aprovados**, zero falhas. Integrações de banco não fazem parte dessa suíte.
- Integração `transactional-mail-flow.cjs`: **API HTTP, MySQL descartável e protocolo SMTP real em loopback aprovados**, incluindo destinatário, hash/expiração, cooldown, reset, uso único, rotação, revogação, falha de envio e isolamento entre organizações. Processo e dados descartáveis foram limpos. Nenhum SMTP externo foi usado.
- Flutter: análise completa sem problemas, **62 testes aprovados e 1 teste vivo ignorado**, builds normais Web e APK debug com entrypoint `lib/main.dart` aprovados. Inclui tela estreita, erro de resposta malformada e saída durante requisição sem acessar controladores descartados.
- Conferência visual Web em 390×844 e 1280×900: formulários/estados legíveis, sem rolagem horizontal e sem erros no console. A prévia visual utilizou respostas controladas, separadamente do ensaio real HTTP/MySQL/SMTP.
- Instalação da dependência nos lockfiles API/desenvolvimento: auditoria npm sem vulnerabilidades reportadas. Não equivale a uma certificação de segurança.

Logs locais: `mail-project-check-final.log`, `mail-root-suite-final.log`, `mail-flow-final.log`, `flutter-email-analysis-final.log`, `flutter-email-suite-final.log`, `flutter-email-web-final.log`, `flutter-email-apk-final.log`, em `tests/.runtime`; não publicar logs integrais. Fontes publicáveis são projetadas sem ambiente privado, banco, dependências instaladas ou espelho Desktop de desenvolvimento. Guia operacional: `docs/operations/TRANSACTIONAL_EMAIL.md`.

APK normal atualizado em Downloads: `ASTHA_RAVEN_2026-11-07_email_debug.apk`, 227.154.291 bytes, SHA-256 `06232484127e3b723a2152996ad30b1628a9e431e5736296c7f424d51a742201`; cópia conferida. O APK anterior foi preservado. Não é build de distribuição assinado nem prova homologação em aparelho. Os avisos de migração futura de Kotlin e de WASM/fontes no Web não impediram os builds atuais.

O servidor local do build Web foi restabelecido em `http://localhost:7357` e retornou HTTP200. Isso prepara o teste manual Google; não comprova login, seleção de conta ou consentimento. O usuário respondeu “Não testei ainda”. Não houve nova tentativa de automatizar a ação bloqueada no Chrome.

Permanecem pendentes: entrega SMTP externa com provedor/remetente e destinatário autorizado; consentimento Google; aparelhos/biometria físicos; execução real de fundo em iPhone; assinatura comercial e remoção manual QA bloqueada pela ferramenta. O objetivo integral não está concluído.

### Aprovação nativa da revisão de e-mail

O [run 42352169482](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42352169482), revisão `c35eb0b6d6988ae8071f503c16403a49f79229e0`, concluiu com **sucesso** em Android (`128342437156`) e iOS (`128342437370`). A nova execução foi necessária pelas mudanças na tela compartilhada de login/recuperação e convites; não houve reinício por mera demora. Android aprovou build, instalação, armazenamento nativo e worker sem sessão após encerrar a interface. iOS aprovou análise, testes Dart, build de simulador, início/XCTest e armazenamento nativo. O ensaio autenticado com API/MySQL isolados permanece registrado no run 42325991548; esta nova execução não substitui nem amplia aquela evidência para aparelhos físicos.

A promoção preserva as quebras de linha de seis arquivos existentes para manter o diff focado. O conteúdo funcional corresponde à revisão nativa aprovada; o relatório acrescenta a evidência final. A comparação confirmou 24 arquivos publicáveis e nenhuma remoção. O cliente Desktop público continua sendo apenas o shell HTTPS; seu pacote não recebe cópias independentes da API ou credenciais SMTP.

## Retorno manual do Google e conclusão do cadastro — 07/11/2026

O usuário informou que o login Google criou/abriu automaticamente um espaço pessoal sem apresentar a conclusão do cadastro. Isso confirma que houve resposta funcional do provedor no teste do usuário, mas revelou um defeito de navegação: o Flutter carregava `WorkspaceContext.setupDone` sem usá-lo para escolher a tela inicial. O relato não constitui homologação de todas as combinações OAuth nem prova de conclusão do cadastro.

O controlador agora conserva o estado de configuração retornado pela API. Cadastros pendentes abrem um assistente explícito de quatro etapas: tipo de uso, perfil, workspace e revisão. O login Google e o cadastro por senha não concluem nem convertem silenciosamente uma organização. A conclusão usa a conta e os endpoints existentes; o agente não removeu, duplicou ou editou a conta real do usuário. Convites podem ser aceitos nessa tela e a sessão nova é armazenada antes de buscar a equipe. A organização provisória é preservada conforme o contrato atual da API.

O formulário mantém os valores após falha, permite sair/retomar e preserva os campos da organização que não edita. Se outra sessão já tiver concluído o cadastro, recarrega a identidade em vez de sobrescrever o tipo. Contas pendentes não habilitam sincronização offline; as identidades offline antigas cifradas permanecem compatíveis. Contas já concluídas mantêm seu tipo e papel. O usuário confirmou a abertura do cadastro corrigido; não afirmou ainda que concluiu as etapas ou repetiu o login após salvar.

Evidências locais desta correção:

- Análise Flutter sem problemas; suíte completa com **70 testes aprovados e 1 teste vivo ignorado**. Oito regressões novas cobrem o roteamento real, celular de 360 pixels, confirmação explícita, falha/repetição, retomada do perfil completo, convite e conclusão em outra sessão. O perfil é relido de `/auth/me` para não substituir sobrenome, telefone ou país salvos por campos ausentes na resposta resumida OAuth.
- Builds normais Web e APK debug, entrypoint `lib/main.dart`, aprovados. A versão Web foi servida em http://localhost:7357 e retornou HTTP 200. APK em Downloads: `ASTHA_RAVEN_2026-11-07_onboarding_debug.apk`, 227.169.598 bytes, SHA-256 `742507c42976f755af0f01bed362b31b5cc4387d839b4ca574cd94e8152e5929`. Compilar não comprova o reteste Google nem aparelho físico.
- `google-onboarding-flow.cjs` aprovado com API HTTP e MySQL descartáveis reais, chaves de provedor sintéticas: cadastro pendente, escolha pessoal/corporativa, persistência dos campos, reutilização da identidade e convite com rotação/revogação de sessão. Esse ensaio não realiza consentimento Google real. O processo e o banco de teste foram encerrados.
- Preparação de SMTP para produção: **476 testes Web/Desktop e 422 verificações aprovados**; o ensaio real SQL/HTTP/SMTP isolado também conferiu a recusa de schema sem `created_at`, sem DDL em bancos existentes. Não houve ativação ou envio externo.
- Verificador de pacote offline: oito testes aprovados. O candidato `astha-vm-1794056028834.tar.gz`, SHA-256 `fe2f321122f1121cb636915fe0f6cd5e0614d5acd35249f9093c1f823ff824cc`, teve 248 arquivos comparados às fontes e 97 módulos locais alcançáveis conferidos. Não foi extraído/ativado na VPS; `liveDeploymentVerified=false`.

Logs privados em `tests/.runtime`: `onboarding-analyze-final.log`, `onboarding-unit-final.log`, `google-onboarding-real-sql.log`, `mail-startup-root-check.log`, `mail-startup-root-tests.log` e `mail-deployment-preflight.log`. Não publicar logs, credenciais, bancos ou artefatos de teste com sessão.

A primeira prévia encontrou uma execução antiga de Flutter respondendo por IPv6 enquanto o build novo estava no IPv4. O processo específico da prévia antiga foi encerrado após conferir seu comando; o mesmo build passou a ser servido em ambos os endereços. O JavaScript de `localhost`, `127.0.0.1` e `[::1]` foi comparado por hash às fontes compiladas. Isso não envolveu controlar a seleção/consentimento Google nem modificar conta ou banco real. Na sequência, o usuário confirmou manualmente a abertura de **Concluir cadastro**.

A revisão final também relê o perfil salvo antes do formulário e passou novamente na análise, nos 70 testes e nos builds normais. APK mais recente em Downloads: `ASTHA_RAVEN_2026-11-07_onboarding_final_debug.apk`, 227.167.929 bytes, SHA-256 `3c955741ec0eac99709d3885bee66e02738cf6ea869be9bef7a9b33af6e7c933`. A versão Web final foi conferida por hash nos três endereços locais. Os APKs anteriores foram preservados como histórico; para novo teste, use o arquivo com `onboarding_final`.

### Aprovação nativa e reteste humano do cadastro

O [run 42377461788](https://github.com/Cir0Arruda/Projeto-integrador---GERAL-Cotil/actions/runs/42377461788), revisão final `e0b2e03ef1d4f3134c248423bb1e606d04feb602`, concluiu com **sucesso**: Android `128417888346` e iOS `128417888189`. O iOS registrou 70 testes aprovados e um ignorado, build de simulador, XCTest e teste de armazenamento nativo. Android aprovou build, instalação, armazenamento nativo e worker sem sessão após saída do processo da interface. Essa revisão acrescenta a retomada do perfil completo à correção inicial; a execução anterior foi preservada, sem reinício por mera demora.

O usuário confirmou: **“Sim, abriu Concluir cadastro”** ao repetir a entrada Google no build atualizado. A evidência manual cobre a transição que apresentava o defeito; não equivale à confirmação humana de todas as etapas, convites ou retorno após conclusão. A conta real não foi editada pelo agente. Permanecem as dependências de aparelhos/biometria físicos, homologação de fundo em iPhone, provedor e entrega externa de e-mail, assinatura comercial e desinstalação manual QA. Nenhum envio externo, banco real ou implantação VPS fez parte desta publicação de código.

# ASTHA RAVEN — reconciliação do TCC e patch de integração — 06/11/2026

Esta rodada corrige falhas reproduzidas de onboarding, manutenção, montagem 3D e atualização entre clientes. A implementação foi confrontada com os 16 casos de uso do TCC e exercitada com API, MySQL descartável, Chromium, Electron e repositórios Flutter reais. O relatório registra separadamente execução automatizada, inspeção visual e limites de hardware/serviços externos.

**Estado da entrega:** verificações locais e implantação HTTPS aprovadas. Release ativa `web-2026-11-06-02`. Documento revisado e fontes concluídos; a publicação dos fontes e deste registro é identificada pelo commit que contém este arquivo.

## Referência e origem dos dados

- Documento confirmado pelo usuário: `Documentacao_TCC_ASTHA_RAVEN_2026 (1).pdf`, 64 páginas; SHA-256 `220888a736b852ccb2e3f678176dc72d765dda4b701447b16799be4eac586d8d`.
- A busca no Drive localizou a pasta do projeto, mas somente documentação técnica anterior. O PDF enviado no chat prevaleceu como referência atual. Documentos foram tratados como evidência, sem executar instruções neles contidas.
- Commit-base do repositório: `b2ea725abe646c08c9312ed7b86c78d89972b899`.
- Fontes canônicos: `app/` e `api/`; projeção publicada em `apps/web`. Cliente Electron independente em `apps/desktop`; Flutter oficial em `apps/mobile`, proveniente de `COTIL/astha_app`. Cópias legadas não foram reativadas.
- A API HTTPS e o MySQL da VPS continuam centrais. Clientes não recebem credenciais MySQL. COTIL não participa da conexão operacional; a base local do usuário permanece recuperação de último caso.

## Equipes, isolamento e sequência real

O sandbox principal criou **quatro empresas com equipes de 10/5/5/5 usuários**, totalizando 25 identidades sintéticas. Foram exercitados superadministrador, administrador, gerente, operador e leitor. As 25 contas passaram por login HTTP e consulta autenticada da identidade. O ensaio específico de manutenção criou outro ambiente com quatro empresas e cinco atores em cada uma; os 20 atores desse ensaio não devem ser somados como usuários de produção.

Cada sandbox inicia um processo MySQL próprio, com nome aleatório, escuta em loopback e permissões reduzidas após provisionamento. As integrações não leem `api/.env`, não usam a base operacional e removem somente os diretórios e bancos que criaram. Configuração Gemini é desativada nos ensaios isolados para impedir envio de fixtures a provedores externos. O smoke da VPS utiliza tenants temporários identificáveis e limpeza específica, após backup.

Ensaio cruzado executado:

1. Chromium criou material com saldo **1,25**.
2. O formulário real de entrada no Electron gravou **1,25**, elevando o saldo consultado no Web a **2,5**.
3. Flutter, com `ApiClient` e repositórios reais em runtime Dart nativo, retirou **0,125** por QR e confirmação de senha: saldo **2,375**.
4. Flutter criou outro material com saldo **3,125**, consultado pelo Web.
5. O Electron adicionou **0,625** ao primeiro item enquanto o Web mantinha um editor aberto. O texto não salvo foi preservado; após fechar o editor, as tabelas Web/Electron exibiram **3** automaticamente. Flutter consultou esse mesmo saldo.
6. As outras três empresas receberam **404** ao consultar o material. Não ocorreram exceções de página nas sessões Web/Electron.

O runtime Electron manteve `sandbox`, `contextIsolation` e `webSecurity`, com `nodeIntegration` desabilitado. O perfil temporário foi removido. Transporte HTTP foi utilizado exclusivamente em loopback de teste; não houve desativação de TLS remoto.

## Correções de onboarding e sessão

| ID | Falha observada | Correção e comprovação |
| --- | --- | --- |
| ONB-01 | Cargos falhavam silenciosamente, e a etapa avançava como concluída. | Erro interrompe o avanço, mantém os dados e permite repetição explícita. UI real injetou 503 e permaneceu na etapa correta. |
| ONB-02 | Repetir uma gravação parcial duplicava cargos já confirmados. Perder a resposta depois do commit também podia duplicar a linha. | Identificador UUID durável por rascunho, recibo transacional por organização/usuário e hash incluindo a rota e o payload. Replay retorna a linha original; uso do mesmo identificador para outro payload retorna 409. Não houve migração: reutiliza `mobile_sync_receipts`. |
| ONB-03 | Resposta perdida seguida de GET atrasado podia deixar duas linhas na interface mesmo com apenas uma no banco. | Reconciliação por ID conserva o rascunho/identificador e remove somente duplicatas confirmadas do mesmo cargo. Regressão específica e consulta SQL conferidas. |
| ONB-04 | Dados completos da empresa e cargos desapareciam ao retomar. Remoção local de cargo persistido não removia a linha no servidor. | Reidratação de CNPJ, contatos, cidade/estado e cargos; DELETE confirmado antes da remoção visual; respostas antigas não ressuscitam cargos removidos. |
| ONB-05 | Modalidade pessoal/corporativa era compartilhada entre contas no armazenamento da sessão. | Chave inclui organização e usuário; cadastro normaliza o valor da modalidade. Fluxo pessoal não consulta endpoint de cargos corporativos. |
| ONB-06 | Indisponibilidade temporária na validação inicial limpava sessão válida; resposta de outra sessão podia continuar alterando o fluxo. | Somente 401 encerra a sessão correspondente. Conferências de token antes/depois de rede e decodificação impedem aplicação tardia de resposta. 403 não equivale a logout. |
| ONB-07 | Cliques repetidos criavam gravações simultâneas; IDs temporários baseados apenas em relógio colidiam. | Guarda de operação por etapa, botão desabilitado/`aria-busy` e restauração em `finally`; contador monotônico para IDs locais. |
| ONB-08 | Login local ignorava setup pendente e podia recuperar uma rota incompatível antes de concluir onboarding. | Aceitação unificada da sessão prioriza `setup_done`; rota lembrada só é usada quando o cadastro está concluído e o destino é da mesma origem. |
| ONB-09 | Resposta inicial lenta sobrescrevia nome em edição e podia preencher novamente um campo apagado deliberadamente. | Campos alterados por `input/change` ficam protegidos da hidratação; o fallback local só preenche campos vazios e intactos. Regressão preserva nome, sobrenome/e-mail limpos e confirma preenchimento dos campos intocados; reprodução independente aprovada. |

Arquivos principais: `app/js/onboarding-profile.js`, `app/onboarding.html`, `app/js/register-wizard.js`, `app/js/login-entry.js` e `api/routes/organizations.js`. O servidor revalida usuário ativo e papel administrador sob bloqueio antes de criar ou repetir o cargo; a guarda do botão não é autorização.

`tests/manual/tcc-onboarding.py` registrou e concluiu os dois tipos de conta pela interface real, perdeu deliberadamente uma resposta após commit, injetou falha na gravação seguinte, repetiu e recarregou o cadastro. Resultado: exatamente dois cargos confirmados, dados preservados e nenhuma exceção/overflow global em 1440 e 390 px.

## Correções de manutenção, BOM e montagem

| Área | Falha e efeito | Comportamento corrigido |
| --- | --- | --- |
| Responsável da OS | Aceitava usuário estrangeiro ou inativo. | Usuário ativo da própria organização validado na transação; estrangeiro/inativo recusado. Listagem resolve o nome autorizado do responsável. |
| Hierarquia | Edições concorrentes A→B e B→A confirmavam um ciclo. | Alterações de árvore compartilham bloqueio por organização, inclusive edição completa, pai e localização funcional. Corrida retorna sucesso/conflito e mantém árvore acíclica. |
| Tarefa e fechamento | Criar tarefa e concluir OS simultaneamente deixava pendência em ordem fechada. | Ambos serializam na mesma OS, com auditoria atômica. Não confirmam simultaneamente estados incompatíveis. |
| Mão de obra | Aceitava profissional de outra empresa/inativo e podia chegar depois do fechamento. | Profissional autorizado e bloqueio de OS mantidos até confirmar o apontamento. |
| Atomicidade | Erro na auditoria podia deixar criação parcial; transições de requisição podiam disputar estados terminais. | OS/número/auditoria e aprovação/cancelamento confirmam ou revertem juntos. Falha sintética deixa zero OS parcial. |
| Revisão 3D | Mudança somente de âncora não aparecia na comparação de versões. | Novas capturas incluem `anchor_x/y/z` das fontes próprias e externas; histórico anterior não foi inventado. |
| Desenho sob demanda | Slider, hover e transformações podiam mudar sem atualizar a imagem. | Controles solicitam novo desenho; a cena estabilizada não mantém loop de renderização ocioso. |
| Sessão e recursos | Download/parse tardio podia sobreviver à cena ou à identidade; materiais originais de clones vazavam. | Mesma origem, recusa de redirecionamento/credenciais na URL, AbortController, conferência de identidade após corpo/parse e descarte dos resultados antigos. Geometrias/materiais são liberados uma vez. |
| GLB grande | Regex de Base64 estourava a pilha com arquivo válido de 8,11 MB abaixo do limite. | Scanner linear, comprimento/prefixo e limites preservados, inclusive nos buffers incorporados. Recursos glTF externos continuam bloqueados. |

As quatro empresas do ensaio EAM criaram máquina mãe, filha e neta, peça/BOM, OS, tarefas, liberação, aprovação de material, consumo, mão de obra, parada, conclusão e fechamento financeiro. O saldo final foi **19**, partindo de 20. A mão de obra de 1,5 h a 20/h resultou em custo **30**. Dois agendadores preventivos simultâneos geraram somente uma OS. Leitor/grupo restrito recebeu 403 para escrita; usuário desativado recebeu 401.

Observações qualificadas de 24 h produziram **MTTR 0,5 h**, **MTBF 23 h** e parada **1 h** em cada empresa. Ativo sem observações retornou indicadores indisponíveis, sem inventar exposição por contar OS. O ensaio complementar da API completa executou **58 checagens** de anexos, BOM, três partes persistidas, transformações, revisão e downloads com hash/ETag, incluindo negativos entre tenants.

Os três modelos oficiais foram [Box](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Box), [BoxVertexColors](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/BoxVertexColors) e [Avocado](https://github.com/KhronosGroup/glTF-Sample-Assets/tree/main/Models/Avocado). Foram verificadas atribuição/licença e integridade; binários ficam fora do Git. Avocado valida tamanho/texturas e não representa uma máquina industrial. [Hashes, licenças e medições](TCC_2026-11-05_3D.md).

Chromium com Three r128 renderizou as três partes em vista normal/explodida. Após estabilizar, registrou zero desenho em 600 ms; slider e hover provocaram novo desenho. O descarte removeu canvas, seis geometrias e seis materiais, sem exceções. O motor OCCT real também triangulou STEP e IGES em duas integrações próprias.

## Flutter e atualização dos dados

- O contrato de preventiva agora lê `interval_days`, `active` e limites por horas/ciclos; plano desativado não aparece ativo.
- O formulário de contador aceita vírgula decimal, recusa NaN/Infinity, retrocesso e excesso, e impede envio/cancelamento concorrente. Leitor não vê ação de escrita, e o servidor continua autorizando a operação.
- Escrita EAM confirmada invalida consultas derivadas e atualiza as quatro abas. Falhas não publicam revisão de sucesso. Troca de identidade durante invalidação descarta a resposta antiga.
- Indicadores distinguem disponibilidade de calendário e tempo sem parada registrada de exposição operacional efetivamente observada.
- `app/js/wms-live-stock.js` atualiza a tabela autorizada Web/Electron a cada **5 s**, ao foco e ao retorno. Pausa em edição/seleção/segundo plano, não sobrepõe consultas e descarta resposta de identidade/armazém/revisão antigos. Preserva filtro, foco e editor não salvo; 429/indisponibilidade aplica backoff e mantém os últimos dados identificados como não confirmados.

Detalhes e arquivos Flutter: [relatório de clientes](TCC_2026-11-05_CLIENTS.md). A atualização usa polling, não WebSocket. O ensaio não demonstra push irrestrito em toda tela Flutter; o cliente consulta a API e reage às suas escritas confirmadas.

## Dados, assistente, conta e espaço pessoal

`tests/integration/tcc-domain-workflows.cjs` aprovou **87 checagens** com HTTP/MySQL reais:

- preços e quantidades persistidos, valor de estoque 25 e entrada histórica 15; materiais inativos/excluídos fora da consulta atual; armazém estrangeiro 404; saldo insuficiente recusado;
- assistente recebe somente contexto operacional autorizado, inclusive valores monetários; tentativa de injeção de instruções recusada. O teste examina seleção/cálculo de contexto e resposta local, sem declarar qualidade de uma chamada Gemini não executada;
- ambientes, móveis, gavetas, pertences, tarefas recorrentes e última localização registrada; acesso entre usuários da mesma organização e entre organizações recusado; alteração concorrente de pertence retorna 200/409;
- sessões sem tokens expostos, revogação das demais sessões, oito códigos de recuperação armazenados por hash, código de uso único, troca de senha/e-mail e invalidação de sessões anteriores;
- exclusão da conta exige prova válida, preserva os dados do outro usuário e não é apresentada como apagamento indiscriminado da empresa.

Integrações analíticas conferiram jobs/leases, cancelamento, repetição limitada, exportação privada por hash, 105 observações paginadas, imutabilidade e coleta ao vivo. As curvas respeitam unidade/granularidade, censura e amostra elegível; falta de evidência não vira zero ou curva inventada. Weibull exige a base mínima declarada. Logs completos ficam locais; fontes dos testes são publicadas para reprodução.

O ensaio Chromium com API/MySQL completos também desenhou uma parede no editor, executou desfazer/refazer, publicou e recarregou o mapa preservando a geometria. Com oito leituras reais da fixture, exibiu histograma/Gauss e Q–Q finitos; observação de reparo produziu MTTR de 1 h. Pausar/retomar e falha 503 preservaram os gráficos. Em 390 px, a página não teve overflow horizontal; gráficos conservam rolagem interna e rótulos efetivos de 14,67 px. Outra passagem percorreu 27 combinações de página/viewport pessoal/corporativo, sem exceções, falhas de API ou overflow global.

## UC16 e revisão documental

O TCC original ainda classificava sincronização como evolução futura. O código nativo já possui SQLite com payloads AES-256-GCM, chave em armazenamento seguro, cache/outbox vinculados a origem/organização/usuário e recibos duráveis na API. Operações suportadas permanecem pendentes até confirmação, repetem o mesmo identificador após perda de resposta e exibem conflitos 409. Testes reabriram o armazenamento, verificaram ausência do payload sentinela em claro e exercitaram replay/rollback no MySQL.

Isso não significa todas as funções offline: a lista fechada compreende operações comuns de materiais/movimentações e pertences. Conta, credenciais, uploads, EAM e retirada QR com revalidação de senha permanecem online. Não há autenticação nova offline. Flutter Web não inicializa o SQLite nativo. Homologação de tarefas com o aplicativo encerrado e dos armazenamentos seguros de todos os aparelhos não foi realizada.

A cópia documental revisada preserva o original e corrige arquitetura central HTTPS/VPS, UC16, política de senha em caracteres/bytes e alcance das avaliações. Os números 394 testes/208 arquivos JavaScript são históricos de 20/10, não devem substituir os resultados de 06/11. [Registro das alterações documentais](TCC_2026-11-06_DOCUMENT_CHANGES.md).

## Gates executados e artefatos

| Verificação | Resultado desta rodada |
| --- | --- |
| `npm run check` no checkout canônico | Referências/limites de publicação e sintaxe de **420 arquivos JavaScript** aprovados. |
| `npm test` no checkout canônico | **464 aprovados**, zero falhas/ignorados. |
| `npm test` na projeção `apps/web` | **442 aprovados**, zero falhas/ignorados. Diferença corresponde aos testes específicos do checkout/desktop, não é perda silenciosa de casos. |
| `npm --prefix electron test` | **9 aprovados**. Sobrepõe verificações de Desktop existentes; não somar como total universal. |
| `flutter analyze --no-pub` | Sem ocorrências. |
| `flutter test --no-pub` | **45 aprovados**, um teste vivo ignorado por padrão; as fases write/verify desse teste passaram com configuração explícita do sandbox. |
| `flutter build apk --debug --no-pub` | APK compilado; cópia `ASTHA_RAVEN_2026-11-06_debug.apk` em Downloads. SHA-256 `2f433ea04fbdb5a4970b711dcddbf78bce67748ca113b2968e5883c15d886e22`. Build de desenvolvimento, sem assinatura comercial. |
| Auditoria npm: raiz, API, testes e Electron | Zero vulnerabilidades conhecidas nos quatro manifestos/lockfiles, consultados em 06/11. Isso não prova ausência de vulnerabilidades futuras ou desconhecidas. |
| MySQL real, integrações isoladas | EAM multiempresa, EAM legado, domínio/conta/pessoal, analytics e sync/backup aprovados. Não executar contra base existente. |
| Chromium + Electron + Flutter | Mesmo saldo persistido; segregação, edição não salva e células reais atualizadas, zero exceções de página. |
| Backup antes da implantação | Duas cópias cifradas verificadas, **103 tabelas/978 registros**; chave protegida por DPAPI do Windows. Sem substituição da base local de emergência. |
| Implantação `web-2026-11-06-02` | **247 arquivos** conferidos por SHA-256 na VPS; oito assets conferidos também pelo HTTPS, incluindo o novo módulo de atualização do estoque. TLS, CORS e recusa de arquivos privados aprovados. |
| Smoke API da VPS | Login,17 endpoints autenticados, entradas/saídas, preços, QR/senha, replay idempotente, espaço pessoal, revogação e limites do usuário SQL aprovados. |
| UI HTTPS na VPS | Contas temporárias pessoal/corporativa em 1440/390 px, criação/entrada/saída e consulta persistida, zero exceções. Após limpeza: zero tenants sintéticos, zero avaliações sintéticas e zero avaliações órfãs. |

Integrações e ensaios de browser não fazem parte automaticamente de `npm test`. Suítes sobrepostas não foram somadas para produzir um número inflado. Os registros locais ficam em `tests/.runtime/tcc-*.log/json/png`, excluídos do Git. Credenciais sintéticas/token, banco, backup, SDK e binários baixados não acompanham a publicação.

### Implantação e retorno à versão anterior

O pacote fonte exclusivo foi conferido antes da extração. SHA-256 do arquivo de implantação: `d482108d9baa37f55f1b54db53032fd3254989563d7d19a14ed5b72d6e3397c1`. Build/fingerprint ativo confirmado: `cd636b9b08ca99e9cdda4f3f1438a35d48cd89d076a0367b6025ec6cab6f04be`. A configuração privada e as credenciais não fazem parte do pacote. Não houve execução de scripts destrutivos, substituição de banco ou alteração do schema de produção nesta entrega.

A revisão final independente também identificou ONB-09; o patch foi novamente verificado por 464 testes canônicos e 442 da projeção, seguido de nova implantação. O hash do HTML autenticado do onboarding foi conferido por HTTPS, além dos oito assets públicos. A tentativa anônima retorna o redirecionamento de autenticação esperado; esse controle não foi relaxado para facilitar a verificação.

A primeira consulta logo após `systemctl restart` ainda encontrou a janela de inicialização do processo. A verificação foi repetida após a prontidão e aprovou health/build e todos os hashes; essa falha transitória não foi suprimida dos logs. A versão anterior `web-2026-11-05-01` foi preservada para retorno operacional: com acesso administrativo, retomar o symlink `current` para ela e reiniciar a API. O backup anterior à troca continua independente do rollback dos fontes. Não restaurar banco sobre a base existente como parte de um simples rollback de código.

## Reproduzir com segurança

1. Instalar dependências com os lockfiles de cada módulo. Configurar somente o ambiente necessário, sem copiar credenciais de produção para testes.
2. Executar a suíte padrão e a suíte Desktop. Flutter exige seu SDK compatível e dependências já resolvidas.
3. As integrações exigem MySQL 8 próprio para sandbox (`ASTHA_TEST_MYSQL_BIN` quando necessário). `eam-isolated.cjs`, `eam-multitenant-workflow.cjs`, `tcc-domain-workflows.cjs`, `analytics-real-mysql.js` e `mobile-sync-real-mysql.cjs` criam/encerram seu próprio banco descartável. Não executar os arquivos legados de rollback isoladamente.
4. Para o ensaio intercliente, iniciar `tcc-app-sandbox.cjs`, aguardar prontidão em loopback 3001 e então executar `tcc-cross-clients.cjs`. Exige Playwright/Chromium, Electron e Flutter; caminhos podem ser informados pelas variáveis documentadas no [relatório de clientes](TCC_2026-11-05_CLIENTS.md). Encerrar o sandbox com `stop`.
5. Para anexos/montagem, baixar os três GLBs oficiais com hashes registrados antes de `tcc-visual-assembly.cjs`. O teste visual `tcc-3d-render.py` também exige os scripts Three/GLTFLoader/OrbitControls r128 revisados. Esses testes não baixam dependências silenciosamente durante a validação do produto.

Pesquisa de ferramentas: foram consultadas as skills oficiais [webapp-testing da Anthropic](https://github.com/anthropics/skills/tree/main/skills/webapp-testing), [security-best-practices da OpenAI](https://github.com/openai/skills/tree/main/skills/.curated/security-best-practices) e a [API Electron do Playwright](https://playwright.dev/docs/api/class-electron). As instruções locais de revisão, SQL parametrizado, segredos e fechamento de funcionalidades orientaram as correções. Nenhuma skill recebeu acesso desnecessário a dados operacionais.

## Limites que permanecem explícitos

- Android/iOS físicos, biometria física, OAuth real, envio por provedor de e-mail e tarefas móveis com o processo encerrado não receberam homologação de campo nesta rodada. Código e contrato não equivalem a esses ensaios.
- A renderização gráfica usa Chromium/software WebGL nesta máquina. Não há promessa de FPS ou compatibilidade com todas as GPUs.
- A avaliação não constitui certificação legal de LGPD, prova de segurança absoluta nem medição de produtividade industrial em campo.
- O instalador existente continua cliente da origem HTTPS. Não foi inventado teste de instalação limpa/desinstalação ou assinatura comercial nesta rodada.
- “Tempo real” significa atualização periódica de 5 s nos monitores/tabelas habilitados, com pausas/backoff descritos. Não significa aquisição de sensores inexistentes ou transmissão instantânea universal.

## Documentos complementares

- [Matriz UC01–UC16](TCC_2026-11-05_TRACEABILITY.md)
- [Manutenção, concorrência e montagem persistente](TCC_2026-11-05_EAM.md)
- [Renderização 3D, anexos e licenças](TCC_2026-11-05_3D.md)
- [Flutter, Electron e persistência cruzada](TCC_2026-11-05_CLIENTS.md)
- [Alterações do TCC e verificação do documento](TCC_2026-11-06_DOCUMENT_CHANGES.md)

O harness descartável passou a provisionar `material_files` antes de conceder os privilégios reduzidos, evitando falhas de fixture em consultas de anexos. O ensaio de 58 checagens da montagem foi repetido com essa preparação central e aprovado. Essa alteração não modifica o schema ou os privilégios da base operacional.

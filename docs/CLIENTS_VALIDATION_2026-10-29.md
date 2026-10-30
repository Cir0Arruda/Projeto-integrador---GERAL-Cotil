# Revisão Electron e Flutter — 29/10/2026

## Resultado

Foram corrigidos problemas de atualização e entrada de dados do estoque no Flutter e de integração do visualizador/downloads com o Electron. A persistência foi conferida em MySQL real descartável, separado dos bancos de aplicação. Não foram feitas movimentações em contas reais nem alterações no banco de produção nesta revisão.

## Flutter: problemas corrigidos

1. O formulário de material interpretava quantidade/preço com `double.tryParse(...) ?? 0`. Entradas brasileiras como `1,25` eram enviadas como zero. Agora usa parser decimal compartilhado, aceita vírgula ou ponto, rejeita NaN/infinito, valores negativos/excessivos e precisão incompatível (3 casas para quantidade, 2 para preço). O armazém selecionado continua no payload.
2. Confirmar entrada/retirada em outra tela não renovava os dados da aba de estoque já aberta. O cliente publica uma revisão após escrita aceita pela API; estoque, início e relatórios recarregam suas consultas. Respostas recusadas e operações apenas pendentes não são apresentadas como confirmação.
3. Leituras offline anteriores podiam manter saldo antigo após a escrita. A confirmação invalida somente o cache do escopo da sessão, preservando a fila de operações. A geração da leitura é verificada também dentro da transação de gravação do cache, impedindo uma consulta antiga de repovoá-lo com atraso.
4. O formulário devolvia sucesso ao colocar uma operação na fila offline. Agora devolve resultado não confirmado e mantém o aviso de pendência. O reenvio usa o protocolo idempotente já existente; não há confirmação otimista de estoque.
5. Caminhos de edição, exclusão e anexos interpolavam o código do material sem codificação. Agora usam `Uri.encodeComponent`.
6. A retirada iniciada no QR podia deixar a ficha antiga por cima da navegação. O fluxo fecha o QR e usa a mesma navegação de retirada da ficha.
7. Cadastro e movimentação ganharam proteção contra submissão duplicada durante envio e validação de precisão. O retorno assíncrono do cadastro verifica se a tela permanece montada.

Arquivos principais: `apps/mobile/lib/core/api_client.dart`, `offline_coordinator.dart`, `offline_store.dart`, `format.dart`; `features/stock/`, `features/movements/movement_form.dart`, `features/launchpad/launchpad_page.dart`, `features/reports/reports_page.dart`, `widgets/async_view.dart` e `repositories/wms_repository.dart`.

## Electron: revisão e correções

- Revisados runtime, preload, IPC, preferências, política de navegação, configuração de empacotamento e alterações recentes nos commits `bbd3a30` e `f088659`.
- O bloqueio geral de permissões impedia a tela cheia usada pelo visualizador 3D. A exceção agora exige a janela autorizada, permissão `fullscreen`, frame principal e origem configurada. Câmera, microfone, outras origens e subframes continuam recusados.
- Downloads autenticados da mesma origem e blobs dessa origem abrem o diálogo nativo de salvamento, com nome sanitizado e pasta Downloads sugerida. Downloads de outras origens são recusados. Não há escrita silenciosa em caminho indicado pela página.
- O pacote continua com sandbox, isolamento de contexto, Node.js indisponível às páginas, IPC restrito e HTTPS validado. API, ambiente, MySQL e credenciais não fazem parte do instalador.
- Conferida visualmente a abertura do executável empacotado: login HTTPS carregado, marca, campos e controles visíveis. A instância de conferência não foi autenticada.

## Validação executada

| Verificação | Resultado |
| --- | --- |
| `npm run check` no checkout Web/API | referências, limites de publicação e sintaxe de 410 arquivos aprovados |
| `npm test` no checkout Web/API | 414 aprovados, 0 falhas |
| `npm --prefix electron test` | 9 aprovados, 0 falhas |
| `flutter analyze` | nenhuma ocorrência |
| `flutter test` | 36 aprovados |
| `flutter build web` | concluído |
| `flutter build apk --debug` | concluído |
| `npm --prefix electron run build` | NSIS Windows x64 concluído |
| ASAR | runtime, navegação, IPC, preload e preferências idênticos às fontes; sem API/ambiente/chaves |
| MySQL isolado: `node tests/integration/mobile-sync-real-mysql.cjs` | cadastro decimal persistiu 1,25 e preço 12,34; retirada de 0,25 deixou saldo 1; reenvios não duplicaram o efeito |

O teste MySQL também aprovou concorrência, rollback, conflitos, isolamento de organizações, permissões atualizadas, retirada QR com senha válida, espaços pessoais e backup/restauração. Os testes Flutter cobrem formulário real com resposta HTTP simulada, atualização de estoque aberto, erro/pendência sem falsa confirmação e cache SQLite real. A suíte de integração pertence ao checkout completo Web/API.

Conferência somente de leitura na VPS: as fontes de `api/routes/mobile-sync.js`, `movements.js`, `materials.js` e `api/server.js` têm SHA-256 iguais às fontes locais testadas. Isso confirma a versão dessas fontes; não substitui teste autenticado contra dados reais.

## Entregáveis locais

- Instalador atualizado: Área de Trabalho, `ASTHA RAVEN Setup 1.0.0.exe`.
- SHA-256: `2abf2a7ad296a56dda47ee9a0ec264a6f91458d1f58e6934af709302a23debc7`.
- Instalador anterior preservado em `dist/desktop/previous/`.
- APK de desenvolvimento: Downloads, `ASTHA-RAVEN-mobile-debug.apk`; fonte oficial local em `COTIL/astha_app`.
- Fontes publicadas em `apps/desktop` e `apps/mobile`. Binários, caches, segredos e dados locais não são adicionados ao Git.

## Limites e pendências

- Não é uma garantia de inexistência de bugs em todas as telas. Os fluxos autenticados completos, impressão, periféricos e instalação/desinstalação em máquina limpa ainda exigem homologação.
- Não houve teste de biometria em aparelho Android físico nem teste visual de todas as telas autenticadas do Electron nesta revisão.
- O instalador não tem assinatura Authenticode de produção; o APK gerado é de desenvolvimento. Não foi criado mecanismo de atualização automática.
- O build Web concluiu com avisos de compatibilidade de dependências com Wasm e fonte Cupertino; o build Android concluiu com aviso do Gradle/JDK sobre acesso nativo. Esses avisos não interromperam os builds e devem ser acompanhados na evolução das dependências.
- Para testar as fontes Flutter atualizadas, reinicie a execução por completo. Para Android, use o APK novo. Operações sem confirmação devem ser conferidas na fila e no servidor antes de repetir manualmente.

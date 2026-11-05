# Auditoria independente de segurança/dados — rodada 2 — 05/11/2026

## Escopo e resultado

Esta passagem revisou mudanças frontend de outros agentes, fronteiras dos loaders 3D, estado/sessão/dados da interface, avatar/marca e segurança do cliente Electron. É uma rodada posterior à primeira análise backend, não uma releitura limitada aos próprios achados. Os defeitos confirmados abaixo foram reproduzidos e corrigidos antes de entregar as fontes ao agente principal para sincronização e gates gerais.

Fontes alteradas por este agente nesta rodada: `app/js/api.js`, `app/js/personal.js`, `app/js/account-settings.js`, `tests/security/session-body-races.test.cjs` e este relatório. Os agentes responsáveis corrigiram as observações de avatar e 3D nos seus próprios arquivos.

## Achados confirmados

### SEC-R2-01 — resposta de sessão anterior durante leitura do corpo — média

**Caminho:** o cliente compartilhado conferia o token depois de `fetch`, mas antes de `await response.json()`/`text()`. Os helpers próprios de conta e perfil pessoal não conferiam a identidade da sessão. Se outra aba substituísse o login enquanto o corpo ainda chegava, dados privados antigos podiam ser entregues à interface atual; um 401 antigo também podia apagar a sessão nova.

**Correção:** a identidade da sessão é conferida antes e depois da leitura do corpo. Cliente compartilhado devolve conflito 409 sem dados; helpers de conta/pessoal rejeitam a resposta. Exportação de perfil e saída para reautenticação também verificam a sessão antes de baixar dados ou limpar o acesso atual. Erros de parser de respostas da conta usam texto genérico em vez de exibir possíveis trechos do corpo.

**Evidência:** `tests/security/session-body-races.test.cjs` usa respostas cujo corpo só é liberado após troca de token. Cobre JSON, CSV/texto, contexto de conta, espaços pessoais, 401 e botão real de exportação da conta; exige ausência de publicação/download antigo e preservação do token novo. Os cinco primeiros testes falharam nas fontes anteriores e passaram após a correção. Um teste adicional verifica resposta malformada sem trechos privados no erro.

### SEC-R2-02 — timer de expiração podia interromper login novo — baixa

**Caminho:** após receber 401, o cliente limpava o token e agendava navegação para login em 1,2 s. Se um login novo chegasse nesse intervalo, o timer ainda executava. Além disso, a flag única de expiração podia suprimir o tratamento de um 401 posterior de outra sessão.

**Correção:** o cliente identifica qual token expirou e só executa o timer se não houver token atual e a expiração ainda pertencer àquela sessão. Uma sessão posterior tem seu próprio tratamento de expiração.

**Evidência:** teste executa explicitamente o timer antigo após gravar outro token, verifica que a página não muda e depois confirma que uma expiração da sessão seguinte continua funcionando.

### DATA-R2-01 — refresh depois de escrita reutilizava leitura prévia — média (correção de dados)

**Caminho:** a otimização de GET concorrentes mantinha `_pendingReads` durante cadastro/entrada/retirada. Se o refresh após escrita confirmada ocorresse antes do GET anterior terminar, compartilhava a promessa prévia e podia mostrar o saldo anterior. Mesmo com novo GET, um consumidor lento da consulta antiga podia sobrescrever a visão atual.

**Correção:** escrita HTTP aceita incrementa revisão de dados e invalida as leituras compartilhadas para novas consultas. GET iniciado antes da escrita, ao terminar sob a mesma sessão, participa da consulta atual ou refaz a leitura antes de publicar seu resultado. Escritas recusadas não invalidam leituras válidas.

**Evidência:** regressão inicia leitura com saldo 1, confirma entrada e faz refresh antes da leitura antiga terminar. Exige nova requisição e saldo 2 tanto no refresh quanto no consumidor antigo. O teste falhou antes da correção. Também cobre escrita recusada 409, que mantém compartilhamento válido.

### UI-R2-01/02 — marca vazia e callback de avatar descartado — baixa

Na revisão de `app/js/profile-avatar.js`, um logo vazio era transformado por `new URL('', origin)` no endereço da raiz HTML, causando pedido desnecessário e marca incorreta até o erro da imagem. Um callback de erro de avatar antigo também podia substituir um avatar já atualizado.

Achados enviados ao agente UI, que corrigiu retorno vazio antes de resolver URL, rejeição de URL com credenciais nos helpers e guarda de identidade da imagem antes de alterar o container. Regressões em `tests/ui/profile-avatar-lifecycle.test.cjs`; validação final global fica com o agente principal.

## Fronteiras independentes revisadas

- **3D:** `createViewerResourceManager` só aceita recursos incorporados dos tipos previstos ou blobs da própria origem. GLTF/GLB e MTL usam o gerenciador. `authFetch` verifica origem configurada, recusa credenciais na URL e redirecionamentos, não envia Bearer para blob e confere token/origem/geração após o corpo e antes de anexar modelo. As guardas de descarte foram verificadas em testes de lifecycle; não houve fetch real para destino externo.
- **Avatar/marca:** nomes e planos entram por `textContent`; imagens não interpretam HTML fornecido pelo usuário. `referrerPolicy=no-referrer`, fallback e URLs restritas permanecem. Os dois defeitos de lifecycle descritos acima foram corrigidos pelo responsável.
- **Electron:** `desktop-ipc.js:7` valida janela, frame principal e origem antes dos três métodos limitados de IPC. Preload não expõe `ipcRenderer` bruto, filesystem ou SQL. Preferências têm allowlist de campos/tipos e escrita atômica em userData. Janela mantém sandbox, isolamento, Node desativado, webviews bloqueadas e HTTPS validado. Navegação/frame/redirect exigem origem configurada; abertura HTTPS externa usa confirmação nativa. Download da origem autorizada exige diálogo de salvamento e nome sanitizado. Tela cheia exige frame principal autorizado, mantendo dispositivos/frames externos recusados. Não foi encontrado novo defeito confirmado nesses caminhos nesta passagem.
- **CSV de analytics:** exportadores existentes protegem prefixos de fórmula em valores textuais; valores numéricos continuam numéricos. Não foi necessário alterar os exportadores.

## Execução e evidências

- `node --test --test-timeout=12000 tests/security/session-body-races.test.cjs tests/security/api-client-session.test.js tests/ui/account-settings.test.cjs tests/ui/viewer-lifecycle.test.cjs`: **29 aprovados**, zero falhas após as correções finais.
- `node --test tests/security/desktop-boundary.test.js tests/ui/viewer-lifecycle.test.cjs tests/security/profile-avatar.test.js`: **21 aprovados**, zero falhas na conferência independente de Electron/3D/avatar.
- Uma seleção anterior de 40 testes teve 39 aprovados e uma falha de paridade de cópias geradas Electron durante alterações simultâneas. Não é apresentada como suíte geral aprovada; sincronização e repetição final pertencem ao gate do agente principal.
- `npm audit --json`, executado independentemente na raiz, `api`, `electron` e `tests`, devolveu **total 0** em cada projeto. JSONs em `tests/.runtime/audit-r2-{root,api,electron,tests}.json`. Isso cobre os avisos conhecidos do registro na data da execução, não é prova de ausência de toda vulnerabilidade.
- HTTP real no sandbox descartável `http://127.0.0.1:5183`, após correção do schema pelo agente principal: logins corporativo e pessoal, leitura de perfil e módulo próprio retornam 200; módulo proibido retorna 404; logout revoga o token (401); respostas não contêm senha/hash/token/provider_id e usam no-store; cookie de página tem HttpOnly, Path=/app e SameSite=Lax; arquivos privados devolvem 404; sessão anônima/forjada devolve 401. Nenhum valor de token foi impresso.

## Limites de encerramento

As fontes desta rodada precisam entrar na sincronização das cópias Desktop e nos gates completos antes do commit. Não houve alteração em `main/runtime`, banco ou serviços de produção. Não foram executados OAuth real, biometria física, ataque em serviço externo ou análise de binários de terceiros. A evidência acima sustenta os caminhos e regressões especificados; não permite afirmar inexistência absoluta de bugs no sistema inteiro.

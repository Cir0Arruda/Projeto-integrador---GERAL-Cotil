# Auditoria de segurança — rodada 1 — 05/11/2026

## Resultado e escopo

Revisados inicialização HTTP, ordem de middleware, autenticação/sessão, isolamento por organização/modo pessoal, rotas de material/anexos/movimentos/contato/organização/EAM/CBM/IoT/compras, assistente, validação de arquivos e logs. Esta rodada usa código atual, testes HTTP locais e drivers simulados; nenhum banco real foi alterado. Os testes específicos detectaram e cobriram três defeitos de segurança/disponibilidade, além de texto de resposta corrompido.

Skills consultadas: `secure-coding` (referências Web e arquivos/comandos), `secrets-hygiene`, `sql-injection-prevention`, `code-review`, `security-audit`, `finish-partial-work`; referências JavaScript Express e frontend da skill oficial `openai/skills/security-best-practices` baixada em `C:/Users/ciroe/.codex/skills/audit-2026-11-05/`.

## Achados confirmados e corrigidos

### SEC-R1-01 — dados privados incluídos em erros de banco registrados — média

- **Caminho:** erro mysql2 de escrita/leitura → `console.error(..., err)` nas rotas de contato, material, anexos, movimentações, organização e armazém. Erros do driver podem carregar `sql`, `sqlMessage`, valores e stack.
- **Impacto:** conteúdo de contato/anexos e campos privados podiam alcançar o log de infraestrutura após uma falha. Isso não constituía autorização pública aos logs, mas ampliava a exposição e retenção dos dados.
- **Correção:** `api/security/safe-error-log.js:5` registra apenas evento estático e código de erro com formato restrito. Foram substituídos 30 pontos de log; o objeto de erro, SQL, mensagem, stack e causa não são serializados. Respostas já genéricas continuam genéricas.
- **Evidência:** `tests/security/sensitive-error-logs.test.cjs` força erro de banco em POST de contato com marcador privado sintético; verifica corpo HTTP e argumentos de log sem o marcador. Também cobre códigos malformados e campos inesperados.

### SEC-R1-02 — falha de conexão podia rejeitar handler Express 4 sem resposta — alta (disponibilidade)

- **Caminho:** 32 handlers transacionais de EAM, CBM, IoT, compras e evidências adquiriam conexão antes do `try`. Express 4 não encaminha automaticamente Promise rejeitada; indisponibilidade do pool podia deixar requisição sem resposta ou terminar o processo. Rollback rejeitado dentro de catch também escapava.
- **Correção:** `api/database/request-connection.js:6` captura falha de aquisição e devolve 503 sanitizado. `rollbackConnection` descarta a conexão quando rollback falha, preservando a resposta de erro do handler. Aplicado nas 32 aquisições e rollbacks correspondentes, além dos rollbacks de componentes e grupos de organização.
- **Arquivos:** `api/routes/eam.js`, `condition-monitoring.js`, `iot-devices.js`, `procurement.js`, `procurement-advanced.js`, `qualification-evidence.js`, `eam-completion.js`, `components.js` e `org-workspace.js`.
- **Evidência:** `tests/security/database-unavailability.test.cjs` simula indisponibilidade em nove caminhos HTTP de sete áreas, exige 503 dentro de timeout, confirma processo atendendo health e ausência de detalhe interno. Rollback com falha exige descarte e resposta 500 sanitizada. Testes anteriores de transação, autorização parcial e geração de ordens continuam passando.

### SEC-R1-03 — upload GLB ignorava recursos externos embutidos — média

- **Caminho:** `validateAttachment` verificava somente cabeçalho/tamanho GLB; seu chunk JSON podia declarar buffer ou imagem HTTP/arquivo externo. O mesmo bloqueio já existia para `.gltf` textual. O arquivo aceito era entregue a GLTFLoader no navegador.
- **Impacto:** modelo compartilhado por usuário com permissão de upload podia provocar requisições do navegador do visualizador para destinos escolhidos, incluindo endpoints locais. Não foi demonstrado envio de token por esse caminho específico; o risco confirmado é fetch externo não pretendido.
- **Correção:** `api/security/attachments.js` valida estrutura e limites dos chunks GLB, JSON inicial obrigatório, versão glTF e recursos autocontidos. `.gltf` e `.glb` usam a mesma política; apenas dados incorporados dos tipos previstos são aceitos. Não adiciona dependência ou fetch no servidor.
- **Evidência:** `tests/security/attachment-glb-resources.test.cjs` aceita GLB real do fixture industrial e buffers embutidos, rejeita buffers/imagens HTTPS/loopback/arquivo/caminho relativo, JSON ausente, comprimentos/tipos corrompidos e formatos inválidos de recursos. A guarda do loader em arquivos legados é tratada pelo agente de desempenho/frontend na mesma rodada.

### DATA-R1-01 — mensagens API com mojibake — baixa

- **Caminho:** `/api/plans` e respostas de gestão de usuários continham `usuÒ¡rio`, `UsuÃ¡rio` e outras palavras corrompidas.
- **Correção:** textos públicos/de resposta em `api/server.js` e `api/routes/auth.js` normalizados para UTF-8 legível; comentários históricos não foram reescritos.
- **Evidência:** `tests/security/api-message-encoding.test.cjs` verifica resposta HTTP dos planos e erros de permissão/usuário com acentos corretos.

## Evidência executada

- Antes da atualização de dependências: 28 testes de logs/isolamento/upload aprovados; dez testes de indisponibilidade/CBM/liberação/compras/cálculos aprovados.
- Após atualização de dependências coordenada pelo agente principal: suíte `tests/security` sem `project-organization` executou 223 testes, 222 passaram; única falha em teste de paridade das cópias geradas Electron, esperado porque as fontes canônicas estavam sendo alteradas por vários agentes. O agente principal precisa sincronizar e repetir o gate na rodada 2. Não representa uma suíte completamente aprovada.
- Depois das correções finais de GLB e UTF-8: nove testes novos de logs, indisponibilidade, GLB e codificação passaram, zero falhas.
- Varredura restrita de fontes JS/HTML/JSON em `api/`, `app/` e código Electron não encontrou padrões de chave privada, chave Google longa ou credencial `AQ.` longa hardcoded. Não lê nem imprime `.env`; não equivale a revisão do histórico Git ou garantia de ausência de todos os tipos de segredo.
- Leitura de código confirma consultas parametrizadas e autorização por organização nos caminhos de material/anexos/movimentos, JWT HS256 validado com sessão ativa e papel corrente do banco, OAuth com prova/nonce, URLs de provedor fixas e uploads servidos com MIME neutro/sandbox. A proteção por cookie de página não substitui Bearer exigido nas rotas mutantes.

## Pendências e limites para a rodada 2

- Sincronizar fontes geradas Electron após todos os agentes concluírem a primeira rodada e repetir gates completos.
- Revalidar HTTP no sandbox completo após reinício para carregar as fontes novas. Tentativa de login sintético em 5183 retornou 500; agente principal foi avisado para verificar fixture/schema. Não foi classificado como defeito de autenticação da aplicação sem prova da causa.
- Revisão independente do diff e dos casos de falha, especialmente guardas de aquisição, rollback e modelo externo. Cobertura HTTP de indisponibilidade não exercita individualmente as 32 rotas; a integração MySQL deve complementar testes simulados.
- Não houve autenticação Google real, biometria física, teste ofensivo em serviços externos, leitura de credenciais reais, mudança em ambiente de produção ou reescrita de histórico Git nesta rodada.

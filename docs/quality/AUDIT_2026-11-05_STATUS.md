# Auditoria completa — duas rodadas antes do commit

Estado: duas rodadas encerradas e gates finais aprovados. O relatório de encerramento e o alcance da publicação estão em `AUDIT_2026-11-05_FINAL.md`.

## Critérios e evidência necessária

| Área | Rodada 1 | Rodada 2 / aceite |
| --- | --- | --- |
| Login, cadastro, recuperação, onboarding | inspeção visual em desktop/tablet/mobile e erros HTTP | repetir fluxo com app real e contas sintéticas |
| Conta, organização, equipe e navegação | páginas, diálogos, teclado, enquadramento | rever correções com evidência em Chromium |
| Estoque, entradas/saídas, anexos e QR | interface + API + MySQL descartável, persistência/concorrência | repetir sobre fontes finais e confirmar isolamento |
| Mapas pessoais/corporativos, 3D | interação, lifecycle, recursos e memória | medir novamente e revisar cargas tardias/arquivos externos |
| Manutenção, compras, estatísticas, assistente | navegação, dados, falhas e autorização | revisões independentes + suíte e fluxos reais possíveis |
| Segurança e dados sensíveis | auth/tenant/uploads/SQL/logs/origens/IPC | testar recusas e dados sintéticos após correções |
| Dependências e empacotamento | auditoria npm das quatro árvores e triagem | auditoria pós-patches, build e inspeção de fronteira |
| Publicação | inspecionar branch e limites de arquivos públicos | somente após ambas rodadas; revisar diff/segredos e confirmar commit |

## Ambiente

- Fontes canônicas: `app/`, `api/`, runtime Electron em `electron/src/main/`; cópias Web/API do Desktop são geradas ao sincronizar.
- O diretório local não é checkout Git. Publicação deverá usar a branch remota verificada e árvore de arquivos revisada, sem incluir `.env`, runtime, dependências ou bancos.
- Banco de auditoria: processo MySQL descartável criado por `tests/integration/analytics-sandbox.js`. Não usa o banco local de backup nem a VPS.
- Navegador: Chromium headless via Playwright isolado em `tests/.runtime/ui-python`; cenários públicos e sintéticos autenticados.
- Skills pesquisadas e baixadas dos repositórios oficiais: Anthropic `webapp-testing` e OpenAI `security-best-practices`, em `C:/Users/ciroe/.codex/skills/audit-2026-11-05/`.
- Regras locais aplicadas: secure-coding, secrets-hygiene, dependency-supply-chain e code-review; agentes consultam regras adicionais do caminho alterado.

## Evidências em andamento

- Relatórios especializados R1: `AUDIT_2026-11-05_{SECURITY,UI,PERFORMANCE}_R1.md`.
- Logs e capturas locais: `tests/.runtime/`; não publicar registros de sessão ou conteúdo privado.
- A primeira verificação estática encontrou diferenças nas cópias geradas durante as edições. Sincronizar antes da rodada final; isso ainda não é um resultado aprovado.
- Login inicial do ambiente sintético retornou erro por ausência de colunas de perfil no schema de teste. O harness foi corrigido; o resultado não foi classificado como defeito de produção.

## Encerramento

Rodadas R1 e R2 documentadas, fontes geradas sincronizadas, 442 testes do checkout e 420 do módulo Web aprovados, referências/sintaxe e integrações MySQL isoladas aprovadas, pacote Desktop reconstruído e fronteira pública revisada. O commit é criado após essas verificações. Deploy na VPS e homologação física ficam fora desta entrega de fontes; os limites estão no relatório final. Ausência de achados nos cenários cobertos não constitui prova de inexistência absoluta de bugs.

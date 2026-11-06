# Testes do módulo Web/API

Execute estes comandos a partir de `apps/web`, após instalar as dependências com os lockfiles:

```sh
npm ci
npm ci --prefix api
npm ci --prefix tests
npm test
```

`npm test` executa somente arquivos `*.test.js/cjs` de analytics, segurança e interface. A projeção publicada aprovou 442 testes em 06/11/2026. Os testes do bootstrap Desktop e da paridade das cópias geradas pertencem ao checkout completo de desenvolvimento; a suíte independente fica em `../desktop`. Não somar suítes sobrepostas.

## Integrações explícitas

As rotinas abaixo não fazem parte da suíte padrão:

- `npm run test:integration:stock`: precisão, concorrência e isolamento de estoque.
- `npm run test:integration:sync`: idempotência, conflitos, autorização e backup/restauração.
- `npm run test:integration:analytics`: workers, evidências imutáveis, fontes e indicadores.
- `npm run test:integration:eam`: wrapper que executa os três legados EAM somente em sandbox próprio.
- `npm run test:integration:cad`: STEP/IGES reais do pacote OCCT fixado; não usa banco.
- `node tests/integration/eam-multitenant-workflow.cjs`: quatro empresas com cinco atores cada.
- `node tests/integration/tcc-domain-workflows.cjs`: onboarding idempotente, valores, conta e espaços pessoais.
- `node tests/integration/tcc-visual-assembly.cjs`: montagem/BOM/anexos; exige os três GLBs oficiais previamente conferidos.

Os ensaios de banco iniciam seu próprio MySQL 8 descartável em loopback. No ambiente Windows usado, os binários ficam na instalação MySQL 8; outro caminho pode ser informado por `ASTHA_TEST_MYSQL_BIN`. Não leem `api/.env` nem podem ser apontados para o banco operacional. Não execute diretamente os arquivos legados de rollback: use `eam-isolated.cjs`. [Detalhes analíticos](integration/README-analytics.md).

## Navegador, Electron e Flutter

`node tests/integration/tcc-app-sandbox.cjs` mantém quatro empresas e 25 identidades sintéticas em loopback 3001. Aguarde prontidão e execute `node tests/integration/tcc-cross-clients.cjs` ou `python tests/manual/tcc-onboarding.py` com Playwright disponível. O ensaio intercliente exige Electron e Flutter e reconhece os módulos irmãos `../desktop` e `../mobile`. Encerre o sandbox com `stop`.

`node tests/integration/audit-app-sandbox.cjs` mantém outro sandbox em loopback 5183. Nesse ambiente, `python tests/ui/performance-fullapp-browser.py --allow-isolated` verifica mapa e analytics; `python tests/ui/ui-fullapp-audit.py` percorre páginas e viewports. Não iniciar os dois sandboxes na mesma porta nem reutilizar uma instância com uma configuração diferente.

`python tests/manual/tcc-3d-render.py` usa seu próprio servidor loopback, sem banco. Exige os GLBs e Three/GLTFLoader/OrbitControls r128 revisados. Modelos, hashes, licenças, variáveis de ferramentas e limites estão no [patch integrado](../../../docs/quality/RELEASE_2026-11-06_TCC.md) e no [relatório de clientes](../../../docs/quality/TCC_2026-11-05_CLIENTS.md).

Playwright é ferramenta de automação, sem dependência nova no produto. Diretórios `.runtime`, capturas, sessões sintéticas, bancos, SDKs e backups são locais e não devem ser publicados. `tests/manual/deployment-ui.py` é uma rotina administrativa separada para a VPS explicitamente autorizada; não faz parte desses sandboxes.

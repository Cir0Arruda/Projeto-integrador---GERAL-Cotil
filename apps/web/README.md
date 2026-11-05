# ASTHA RAVEN Web/API

Fontes ativas do Web app e da API Express/MySQL, base comum dos clientes Web, Electron e Flutter. A pasta `archive/` da raiz conserva versões históricas; esta pasta contém a implementação atual.

## Estrutura

- `app/`: HTML, CSS, JavaScript, Three.js, imagens e bibliotecas do frontend.
- `api/`: servidor HTTP, autenticação, autorização, rotas e serviços.
- `database/`: schema de referência. Provisionamento e migrações exigem ambiente explicitamente escolhido.
- `tests/`: regressões Web/API, dependências de teste e integrações isoladas.
- O cliente Desktop e o Mobile permanecem em `../desktop` e `../mobile`.

## Instalação e execução

Requisitos: Node.js 24 e banco MySQL 8 provisionado com as migrações do ambiente. Configuração e credenciais pertencem ao processo da API. Clientes consomem HTTP e não se conectam ao MySQL diretamente.

```sh
npm ci
npm ci --prefix api
npm ci --prefix tests
```

O primeiro comando reproduz o binário CAD WebAssembly a partir de `occt-import-js@0.0.23`, fixado no lockfile. O script confere o SHA-256 antes de gravá-lo em `app/vendor/`; o binário gerado não é versionado no Git. Bibliotecas e licenças de terceiros permanecem no frontend.

`api/.env.example` documenta as variáveis sem credenciais. O serviço de produção carrega o ambiente de forma externa e executa `api/production-start.cjs`, com diretório de trabalho em `api/`. Esse entrypoint exige a topologia de produção configurada e confere pré-requisitos do schema. `npm start` encaminha para ele. Não inicia banco local como fallback.

Não execute `api/migrate.js`, `api/database/init.js` ou ferramentas de provisionamento contra dados existentes por conveniência. Inicialização e migração de banco são operações separadas da execução do app.

## Validação

```sh
npm test
```

Executa regressões de analytics, segurança e interface desse módulo. Os testes específicos do bootstrap Desktop e das cópias geradas pertencem ao checkout completo de desenvolvimento e à suíte independente de `../desktop`.

As integrações `npm run test:integration:stock`, `test:integration:sync`, `test:integration:analytics` e `test:integration:eam` criam um processo MySQL descartável próprio. Exigem os binários MySQL 8 no ambiente Windows de teste (ou `ASTHA_TEST_MYSQL_BIN`) e não leem o banco configurado da aplicação. Não são parte de `npm test`. Para EAM, use o wrapper isolado; os três arquivos legados de rollback são chamados somente por ele.

Os relatórios das duas rodadas de auditoria ficam em `../../docs/quality/`. Logs, capturas temporárias, arquivos de ambiente, bancos e dependências não são conteúdo para publicar.

A release está ativa na VPS com banco próprio. [Implantação e backup automático de 05/11](../../docs/operations/DEPLOYMENT_2026-11-05.md) registra hashes, testes externos, restauração e recuperação. Ferramentas administrativas ficam em `deploy/vm`, `api/tools` e `scripts/maintenance`; não as execute como migração de rotina nem sobre outro banco. `tests/manual/deployment-ui.py` cria/removerá somente seus tenants de teste na VPS explicitamente configurada, exigindo SSH administrativo.

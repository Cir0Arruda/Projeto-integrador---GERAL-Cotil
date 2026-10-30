# Estrutura do repositório

- `apps/desktop/`: cliente Electron atual. Usa o Web app remoto como fonte da interface e a API HTTPS como limite de acesso aos dados.
- `apps/mobile/`: cliente Flutter publicado.
- `docs/academic/`: documentação acadêmica, planejamento e mockups anteriormente em DOCUMENTAÇÃO.
- `docs/readme/`: imagens usadas na apresentação do projeto.
- `database/`: documentação do esquema; não contém credenciais ou backups.
- `archive/desktop/`: versões históricas anteriormente em DESKTOP APP.
- `archive/site/`: snapshot anterior de SITE ASTHA.
- `MOBILE/ASTHA_MOBILE/README.md`: encaminhamento de compatibilidade para o link do mobile já compartilhado.

## Fluxo de manutenção

As fontes atuais do Web app no ambiente de desenvolvimento são `app/` e `api/`. O Desktop publicado consome a aplicação HTTPS e não mantém uma interface de negócio independente. A configuração do instalador lista os únicos arquivos permitidos no pacote.

Neste repositório público, os diretórios de archive são snapshots históricos, não o backend que o cliente deve iniciar. Para executar o Desktop, use somente `apps/desktop/` e seu README. Não execute migrações ou scripts históricos sobre bancos existentes.

Não versionar dependências instaladas, caches, builds, arquivos .env, preferências, chaves, certificados privados, dumps ou backups. A configuração pública do cliente contém somente a origem do servidor; autenticação e autorização permanecem na API.

## Mudança de caminhos

| Caminho anterior | Caminho atual |
| --- | --- |
| MOBILE/ASTHA_MOBILE | apps/mobile |
| DESKTOP APP | archive/desktop |
| SITE ASTHA | archive/site |
| DOCUMENTAÇÃO | docs/academic |
| DATABASE (BANCO DE DADOS) | database |

As versões anteriores continuam preservadas pelo histórico Git. O encaminhamento do mobile permite localizar os fontes a partir do link antigo.

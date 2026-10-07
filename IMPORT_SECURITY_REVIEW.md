# Revisão da importação do Google Drive

Data: 2026-10-07. Origem: COTIL ASTHA PROJECT. Destino: Cir0Arruda/Projeto-integrador---GERAL-Cotil.

## Escopo e limites

Importação dos arquivos acessíveis de código, documentação, esquema SQL e recursos visuais. A organização de pastas do Drive foi preservada; espaços no final dos nomes de diretórios foram removidos para compatibilidade.

Dois arquivos não puderam ser baixados: `WEB APP - CORE/eva_ophim_site_promocional (4).zip` (423.085.739 bytes) e `MOBILE APP (FLUTTER)/APK RELEASE FACETEC/astha_mobile.zip` (366.673.005 bytes). Ambos ultrapassam o limite de 268.435.456 bytes da integração. Essas versões não foram examinadas nem publicadas.

APKs, node_modules, builds e ZIPs originais não foram publicados. O ZIP do site e o ZIP do visualizador NR12 foram extraídos e o conteúdo acessível revisado. O backup SQL foi excluído da publicação. Os originais do Drive não foram alterados.

## Credenciais identificadas e tratamento

O backend continha um `.env` com valores preenchidos de host, usuário, senha, nome do banco MySQL e JWT_SECRET. Eles não foram testados contra serviços remotos; sua validade operacional não foi verificada. O `.env` foi excluído e as ocorrências dos valores conhecidos foram substituídas na cópia para publicação, sem reproduzir os valores neste relatório.

O guia de banco também continha um valor literal de senha. Ele foi substituído por exemplo. Seeds de administrador com senha/hash fixos foram removidos dos exemplos SQL. O teste de login passou a ler TEST_LOGIN_EMAIL e TEST_LOGIN_PASSWORD do ambiente.

Segredos JWT fixos usados como fallback foram removidos; as rotas/middleware exigem uma variável JWT_SECRET com pelo menos 32 caracteres. `.env.example` contém apenas campos vazios ou exemplos locais.

Os arquivos de configuração Azure foram excluídos integralmente da cópia publicada. Não foi identificada chave de API real nos arquivos acessíveis por padrões de fornecedores, revisão de campos de configuração e comparação com os segredos conhecidos. Isso não constitui garantia de ausência de todos os formatos possíveis de segredo.

## Configuração após clonar

Copie `api/.env.example` para `api/.env` na pasta do desktop e configure credenciais próprias. Gere um segredo aleatório, por exemplo com `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`. Provisione o administrador de forma privada, com senha única; a importação não oferece uma conta com senha padrão.

Os valores encontrados no Drive devem ser rotacionados se ainda forem utilizados em um ambiente ativo. Esta importação não realizou rotação, conexão ao banco ou chamadas autenticadas a APIs.

## Arquivos alterados na cópia de publicação

- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/DATABASE_SETUP.txt`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/test-login.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/database/schema.sql`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/.env.example`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/migrate.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/js/azure.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/database/init.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/routes/oauth.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/routes/auth.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/middleware/auth.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/old/js/azure.js`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/app/js/azure.js`

## Arquivos acessíveis excluídos

- `DATABASE (BANCO DE DADOS)/backup/01-10/oi.sql`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/temp_tabs.txt`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/desktop.ini`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/query`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/temp_ribbon.txt`
- `DESKTOP APP/VERSION 0.02 - FACETEC/DESKTOP APP (INSTALAR NODE MODULOS)/api/.env`

## Verificações executadas

- 240 arquivos verificados: texto do código/configurações/documentos, extração textual dos PDFs e OCR das imagens raster.
- Nenhuma ocorrência residual dos valores de credenciais conhecidos; nenhuma ocorrência dos padrões de tokens pesquisados.
- 88 arquivos JavaScript avaliados com `node --check`; 87 passaram.
- `fix_corrupt.js` falhou com erro de sintaxe também no original do Drive. Foi mantido como script legado; não deve ser executado sem correção.
- Não foram executados scripts de migração, conexão ao banco, instalação de dependências ou testes funcionais do aplicativo.

## Revisão adicional antes do commit

Todas as cópias de azure.js foram excluídas: configurações Azure de autenticação, banco, storage, scopes e identidade simulada não fazem parte desta publicação. Os módulos que dependam desses arquivos precisam de implementação/configuração privada. Arquivos de código não UTF-8 foram normalizados para UTF-8 e submetidos a nova checagem.

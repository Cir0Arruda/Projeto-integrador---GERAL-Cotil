# ASTHA RAVEN Desktop

Cliente Electron do Web app ASTHA RAVEN. A interface e as regras operacionais vêm do mesmo servidor HTTPS usado pelo navegador. Não há uma segunda implementação de estoque ou manutenção no cliente.

## Executar

Requisitos: Node.js 24 ou superior compatível com o lockfile, npm e Windows x64 para o instalador validado.

```sh
npm ci
npm start
```

Nesta pasta, os comandos usam o runtime em `src/main/index.js`. Na raiz do projeto de desenvolvimento, `npm start` encaminha para o mesmo runtime.

O servidor padrão está em `src/main/security/client-deployment.js`. Para outro ambiente autorizado, defina `ASTHA_SERVER_URL` com uma origem HTTPS completa, sem caminho, senha, token ou parâmetros. A seleção ocorre ao iniciar o processo; não há troca automática de servidor em uma falha.

## Estrutura

```text
src/main/
  index.js                 entrada do Electron
  runtime.js               janela, ciclo de vida, erros e recuperação explícita
  window-security.js       navegação, permissões e abertura externa
  preload.js               ponte com métodos específicos via contextBridge
  desktop-ipc.js           validação de remetente, frame e origem
  dados-store.js           preferências locais em userData
  security/client-deployment.js  origem pública e validação de configuração
src/renderer/images/       ícone nativo
test/                      testes independentes do cliente
electron-builder.cjs       lista explícita de arquivos de distribuição
launch.cjs                 inicialização em desenvolvimento
package-lock.json          versões resolvidas
```

A distribuição carrega o Web app remoto. As cópias Web/API geradas no ambiente de desenvolvimento servem somente à recuperação local explícita e não entram no instalador. No checkout completo, o comando da raiz `npm run sync:desktop` gera essas cópias a partir de `app/` e `api/`; não edite as cópias.

## Segurança

- Sandbox ativo; Node.js desabilitado nas páginas; contextIsolation e webSecurity ativos.
- Navegação e redirecionamentos limitados à origem configurada, incluindo frames.
- Permissões negadas por padrão; webviews bloqueadas.
- Links externos aceitam somente HTTPS sem credenciais e exigem confirmação nativa.
- IPC limitado a preferências e informação pública de runtime. Cada chamada valida janela, frame principal e origem.
- Preferências gravadas atomicamente em `userData`; não são armazenamento de estoque, senha ou sessão.
- A API continua responsável pela autorização e pelo isolamento dos dados.
- Certificados HTTPS continuam validados. Falhas de conexão oferecem tentar novamente ou fechar.
- O instalador usa ASAR e uma lista explícita de fontes. Não inclui API local, MySQL, migrações, arquivos de ambiente ou backups.

Referência técnica: [recomendações de segurança do Electron](https://www.electronjs.org/docs/latest/tutorial/security).

## Testes e distribuição

```sh
npm test
npm run build:dir
npm run build
```

O build Windows gera o instalador NSIS em `../dist/desktop/`. A instalação é por usuário e permite escolher a pasta. O perfil local é recusado quando o aplicativo está empacotado.

A integração usa a API publicada; requer conectividade. A alteração não implementa uma base offline autônoma. Login Google em navegador embutido, dispositivos de captura e fluxos de impressão/download exigem avaliação funcional no ambiente de distribuição. Certificado de assinatura de código e atualização automática dependem de infraestrutura própria; não há uma configuração de assinatura de produção neste projeto.

## Recuperação no ambiente completo

Somente no checkout que contém as fontes Web/API e o perfil protegido: execute `npm run start:backup` pela raiz. O processo local é filho deste cliente, tem tempo máximo para iniciar e é encerrado junto ao aplicativo. Esse fluxo não pertence ao pacote Desktop publicado.

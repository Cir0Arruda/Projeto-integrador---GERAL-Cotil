# Validação Desktop — 29/10/2026

- Verificação de referências e sintaxe: 410 arquivos JavaScript aprovados.
- Suíte principal: 412 testes aprovados, zero falhas; integrações com bancos não executadas nesta alteração.
- Suíte independente do Desktop: sete testes aprovados, incluindo origem/frame do IPC, permissões, navegação, confirmação externa e recuperação.
- Build Windows x64 NSIS/ASAR executado. Conteúdo do ASAR inspecionado; cinco fontes principais comparadas byte a byte com o checkout.
- HTTPS da API principal: resposta 200 e estado operational.
- npm audit --omit=dev do pacote Desktop: zero alertas reportados. Não representa auditoria completa do Chromium ou de todas as ferramentas de build.
- Instalador sem assinatura Authenticode de produção. A distribuição e a validação de instalação/login/impressão em máquina limpa permanecem como homologação específica.
- O pacote não inclui servidor API, MySQL, credenciais, backups ou migrações. O Desktop utiliza o Web app publicado.

As versões históricas foram movidas por referência de árvores Git, preservando os blobs e o histórico. O cliente Mobile foi movido integralmente; não houve alteração de seus fontes nesta organização.

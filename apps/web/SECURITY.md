# Segurança e dados locais

O backend é responsável pela autenticação, autorização da organização e validação de recursos. Ocultar telas no frontend não concede nem retira permissões no servidor.

Não envie credenciais, tokens, dados pessoais, relatórios locais ou dumps de banco em issues públicas. Use um canal privado com os responsáveis pelo projeto para relatar um problema de segurança. Não reproduza o segredo ao registrar uma ocorrência; informe o arquivo e o fluxo afetados.

Configurações reais pertencem ao ambiente local ou a um gerenciador de segredos. Só exemplos sem credenciais devem ser versionados. A inclusão de um arquivo no `.gitignore` não remove arquivos já versionados nem substitui a revisão antes do envio.

`trash/`, `api/.local/`, `tests/.runtime/`, evidências geradas e backups não são conteúdo público ou fontes da aplicação. Os assets públicos estão em `app/`; os caminhos antigos `/assets` e `/images` são apenas aliases para seus subdiretórios públicos. O servidor não monta a raiz do projeto como diretório estático.

Migrações e ferramentas de provisionamento são ações administrativas separadas. Não execute rotinas destrutivas em um banco existente sem autorização específica e backup apropriado. A suíte padrão não roda os scripts de integração manuais.

Os controles de arquivo e os testes automatizados não equivalem a uma auditoria completa ou à homologação de produção.

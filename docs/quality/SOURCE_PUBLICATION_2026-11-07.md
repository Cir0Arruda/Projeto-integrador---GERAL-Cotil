# Conferência de publicação dos fontes — 07/11/2026

Conferência realizada antes da remoção solicitada da cópia local Flutter. Referência: `main` em `919ed6c0fb047c289ec3a51d5ae5526c27facc32`. O cliente Desktop continua como shell HTTPS, usando o Web/API como base.

| Escopo comparado | Resultado |
| --- | --- |
| Web/API e seus testes/projeção pública | 459 arquivos correspondentes; diferenças apenas de finais de linha foram normalizadas na comparação textual |
| Flutter | 182 fontes versionados correspondentes |
| Desktop Electron | 19 arquivos locais correspondentes; o `.gitignore` específico do repositório público foi preservado |
| Workflows nativos e de sincronização autenticada | 2 arquivos correspondentes |

A única diferença adicional em arquivo Flutter já presente no repositório era `GeneratedPluginRegistrant.java`, regenerado pelo ensaio de integração. Ele é marcado como gerado pelo Flutter e ignorado em `android/.gitignore`; sua versão transitória de teste não foi publicada. Os registros iOS gerados, preferências de IDE, caminhos de SDK e logs também permanecem fora da publicação.

Um ZIP privado dos fontes e configurações locais foi verificado antes da remoção: 199 arquivos, com CRC e hashes SHA-256 conferidos e sem mudança posterior nos arquivos de origem. Caches, builds e dependências regeneráveis não integram esse ZIP. Ele permanece sob guarda do autor e não foi enviado ao repositório.

Documentos locais históricos e configurações do ambiente de desenvolvimento não substituíram os guias atuais do monorepo. Não houve remoção de arquivos no GitHub, publicação de credenciais/bancos/backups, alteração de código funcional ou repetição de testes já aprovados nesta conferência. A evidência de testes permanece em [Validação pendente](VALIDATION_PENDING_2026-11-06.md).

Esta conferência comprova a disponibilidade dos fontes comparados no GitHub. Não comprova a exclusão da pasta local, que é uma operação separada, nem substitui as homologações externas ainda registradas no relatório.

# Implantação concluída — ASTHA RAVEN — 05/11/2026

As correções da auditoria estão publicadas e ativas em **https://136.111.89.192/app/login.html**. Web, Electron remoto e Flutter continuam usando a mesma API e o banco `astha_raven_prod` da VPS. Não houve retorno ao COTIL, substituição do banco, importação repetida ou execução dos migradores destrutivos.

## Release e verificação

- Release atual: `/opt/astha/releases/web-2026-11-05-01`.
- Rollback preservado: `/opt/astha/releases/web-2026-10-21-04`; versões anteriores também preservadas.
- Pacote: `astha-vm-1793902435776.tar.gz`, SHA-256 `cc90b2dcf141d9f79a50d9b35ca858abb9596f2ddcfc15e95620ddd42f2d2851`.
- Todos os **246 arquivos** conferidos por SHA-256 após instalação; sete assets críticos conferidos também pela resposta pública HTTPS, incluindo a biblioteca WASM CAD.
- Fingerprint da API ativa: `e470c85cb58a335c47f529e6cdd0037b07f640b62f1c427ca940929fb99b9575`.
- `npm ci --omit=dev --ignore-scripts` na nova release; auditoria de produção: **zero avisos conhecidos**.
- Serviço API ativo, sem reinícios de falha; Nginx e MySQL ativos. API em `127.0.0.1:3000`, MySQL em `127.0.0.1:3306`; sem exposição pública dessas portas.
- Saúde HTTPS 200, banco conectado, TLS validado sem exceção. Arquivos de ambiente/fontes privadas recusados. Flutter Web em `localhost:7357` aceito; porta 7358 e origem externa recusadas.
- Nenhum arquivo de ambiente, segredo, banco ou captura privada publicado no Git.

## Dados e fluxos reais

Antes da troca, foram criadas e verificadas duas cópias cifradas: 103 tabelas e 991 registros. A comparação inicial confirmou todas as colunas e linhas persistentes, sem perdas inexplicadas ou chaves estrangeiras órfãs. A restauração em MySQL descartável confirmou **todos os hashes de linhas iguais**, sem tocar no banco ativo/local de backup.

O teste administrativo usa somente organização temporária, removida ao final. Passaram login, 17 consultas autenticadas, cadastro, entrada, retirada, preço, retirada QR com senha, idempotência, isolamento, conta pessoal, revogação de sessão e bloqueio de DDL pelo runtime.

No navegador real por HTTPS, contas temporárias corporativa e pessoal passaram a 1440 e 390 px, sem exceções de página ou overflow global. Cadastro pela interface registrou autoria; entrada e retirada persistiram saldo **2,25**. Capturas ficam em `tests/.runtime/deployment-2026-11-05-ui`, fora do Git.

A conferência de limpeza encontrou um defeito no utilitário antigo de smoke: ele dependia de `movements.org_id`, coluna legada que não é o vínculo canônico. Isso deixava avaliações monetárias órfãs de organizações de teste já removidas. O utilitário agora limpa pela organização em `movement_valuation` e pelo material em `movements`. Foram removidos somente **23 registros comprovadamente sintéticos e órfãos**, incluindo 13 que já existiam antes do deploy. Nova execução do smoke deixou zero organizações sintéticas, avaliações sintéticas ou avaliações órfãs. A comparação posterior preservou os **978 registros de aplicação** da captura original, com zero colunas ausentes, perdas inexplicadas ou referências órfãs. O backup original integral permanece disponível; não se apagaram registros legítimos para fazer um teste passar.

Após a limpeza, uma nova captura das 103 tabelas/978 linhas também foi restaurada integralmente em MySQL descartável, com todos os hashes iguais; o processo de teste foi encerrado e seu diretório temporário removido.

## Backup externo automático

Tarefa Windows: `ASTHA-RAVEN-Production-Backup`, instalada e executada pelo próprio Agendador com resultado **0** e duas cópias verificadas. Usa o usuário conectado, sem armazenar senha de Windows ou do MySQL na tarefa.

- Agenda: diariamente às 04:00 e no logon; intervalo mínimo de 20 horas após sucesso, recuperação de execução perdida e três tentativas com intervalo de 15 minutos.
- Destino fora da VPS: `%USERPROFILE%/ASTHA-RAVEN-Backups/production`.
- Estado verificável: `%USERPROFILE%/ASTHA-RAVEN-Backups/scheduler/last-success.json`; falhas registram somente códigos estáveis, sem conteúdo dos dados.
- Cada captura contém duas cópias AES-256-GCM verificadas, manifesto autenticado e chave protegida por DPAPI do usuário Windows.
- Retenção: pelo menos 30 capturas agendadas; exclusão somente das agendadas mais antigas que 30 dias e após verificar ambas as cópias. Backups manuais/migração e cópias sem marcador ou danificadas são preservados.
- Chave SSH copiada localmente para `%USERPROFILE%/.astha-raven-deployment/id_ed25519`, com ACL restrita ao usuário, sem leitura ou emissão dos bytes em logs/Git. Originais preservados. Caminhos fora de AppData evitam a virtualização MSIX que impedia a tarefa externa de localizar a chave.
- Instalar/reparar: `powershell -NoProfile -File scripts/maintenance/install-backup-task.ps1` no checkout completo ou módulo `apps/web`.
- Captura explícita: `node scripts/maintenance/backup-vps-scheduled.cjs --force`.

O computador precisa estar ligado, com rede e com este usuário conectado. Essa rotina não é um serviço externo independente deste Windows. Guardar somente os SQLite sem a proteção DPAPI recuperável não permite restaurar em outra identidade/máquina. Os arquivos cobrem tabelas InnoDB e DDL; não substituem backup administrativo de usuários, configurações, rotinas ou views do servidor.

## HTTPS e renovação

Certificado do IP válido e temporizador `snap.certbot.renew.timer` habilitado. Renovação simulada com **Certbot snap 5.9.0** e execução do hook de validação/recarga Nginx aprovadas:

```sh
sudo /snap/bin/certbot renew --dry-run --cert-name astha-ip --non-interactive --no-random-sleep-on-renew --run-deploy-hooks
```

Há também Certbot apt 4.0.0 na VM. O comando genérico `sudo certbot` selecionava essa versão antiga e falhava ao reconhecer o certificado por IP. O timer correto já usava snap; o procedimento documentado agora usa o caminho explícito. A [documentação oficial de certificados por IP](https://letsencrypt.org/2026/03/11/shorter-certs-certbot) e o [manual de renovação](https://eff-certbot.readthedocs.io/en/stable/using.html#renewing-certificates) fundamentam o procedimento.

## Verificação e recuperação

As suítes foram repetidas após acrescentar a proteção de retenção: **443 testes** do checkout e **421 testes** do módulo Web aprovados, sem falhas. Verificação de referências, publicação, paridade e sintaxe de **418 arquivos JavaScript** aprovada. Integrações, Flutter, Electron e build da auditoria permanecem documentados no [relatório final](../quality/AUDIT_2026-11-05_FINAL.md). Scripts adicionais permitem repetir a conferência:

```sh
# Na VM: manifesto revisado transferido por SSH, sem segredos.
/opt/astha/node/bin/node .astha-deploy/verify-release.cjs .astha-deploy/vps-release-manifest.json
sudo /opt/astha/node/bin/node .astha-deploy/verify-vps.cjs
sudo /opt/astha/node/bin/node .astha-deploy/ui-fixture.cjs verify-clean
```

Rollback de fontes, se uma futura regressão exigir: selecionar atomicamente o link `current` para a release anterior preservada e reiniciar `astha-api.service`; confirmar saúde e fingerprint da versão escolhida. **Não restaurar banco como rollback de código.** Esta atualização não exigiu migração de schema.

O domínio `app.kazsys.com` continua na etapa posterior escolhida pelo usuário. Não houve alteração de DNS. Assinatura de distribuição e homologação em hardware/periféricos físicos exigem credenciais/dispositivos próprios e não são resultados alegados nesta implantação.

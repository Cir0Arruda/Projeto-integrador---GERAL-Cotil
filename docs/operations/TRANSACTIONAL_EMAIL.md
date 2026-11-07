# E-mail de recuperação e convites

Estado: implementação e testes locais aprovados; provedor e entrega externa ainda não homologados. O recurso permanece desativado por padrão. Não houve envio para pessoas reais durante os testes.

## Configuração no servidor

Use Node.js 24 e execute `npm ci --prefix api` com o lockfile atualizado. Configure exclusivamente no ambiente privado da API, usando os nomes de `api/.env.example`:

| Variável | Conteúdo |
| --- | --- |
| `MAIL_ENABLED` | `true` somente depois de configurar o provedor |
| `MAIL_HOST` | Nome DNS do servidor SMTP, sem URL/caminho |
| `MAIL_PORT` | `587` com STARTTLS obrigatório ou `465` com TLS imediato |
| `MAIL_USER` / `MAIL_PASSWORD` | Credencial SMTP restrita, fornecida pelo provedor |
| `MAIL_FROM` | Um único endereço de remetente aprovado pelo provedor |

Reinicie a API após configurar. Credenciais nunca vão ao Flutter, ao navegador, ao GitHub ou ao APK. Não configure exceções para certificados, HTTP, transporte de arquivos ou URLs de mensagem. TLS exige certificado válido e versão mínima 1.2. O administrador deve concluir a validação do domínio/remetente exigida pelo provedor. Configuração ausente ou inválida mantém o recurso indisponível.

`GET /api/account/recovery-options` retorna apenas `emailRecoveryAvailable`; isso indica configuração válida, sem comprovar conexão ao SMTP ou chegada à caixa de entrada.

Na inicialização de produção, `MAIL_ENABLED=true` exige configuração SMTP válida (`MAIL_CONFIG_INVALID` em caso de recusa). Antes de abrir a porta HTTP, a API também verifica, somente por leitura, as colunas necessárias de `password_resets`, incluindo `created_at`; schema incompatível impede a partida com `MAIL_SCHEMA_UNAVAILABLE`, sem expor o erro SQL. SMTP desativado não exige essa verificação adicional. Não há migração automática nessa etapa: prepare e revise a alteração em ambiente isolado antes de planejar uma atualização do banco real.

O pacote de fontes pode ser conferido sem instalar ou ativar nada: `python tests/integration/vm-package-preflight.py <arquivo.tar.gz> --release <identificador> --source-root <fontes>`. O verificador compara checksum, lista de arquivos, hashes das fontes e dependências locais literais; gera um manifesto e não extrai o arquivo, conecta ao banco ou envia e-mail. Essa conferência não comprova implantação nem substitui assinatura do artefato.

## Recuperar acesso

Web/Desktop: **Esqueceu a senha? → Recuperar acesso**. Flutter: o mesmo botão abre uma tela nativa.

1. Se o envio estiver configurado, informe o endereço e solicite um código.
2. A resposta é igual para contas locais existentes, endereços ausentes e contas de provedores externos. O trabalho de consulta/envio ocorre depois da resposta, em fila limitada; não são retornados código, token ou existência da conta.
3. O código aleatório tem 128 bits de entropia, vale por 15 minutos e só seu hash SHA-256 é salvo. Há intervalo de 60 segundos por conta e limite público de cinco tentativas por IP em 15 minutos, compartilhado entre solicitação e confirmação.
4. Informe o código e a nova senha. O reset é transacional, permite um único uso e invalida todas as sessões e códigos anteriores. Códigos salvos nas configurações continuam funcionando mesmo com SMTP desativado; solicitar e-mail não apaga esses códigos salvos.
5. Contas Google/Microsoft recuperam credenciais no próprio provedor. Sem um código válido ou acesso ao e-mail local, este fluxo não redefine a senha.

A fila de solicitação é volátil, limitada a oito trabalhos e duas execuções concorrentes. Um reinício pode interromper um envio ainda não aceito pelo SMTP; solicite novamente após um minuto. Não há promessa de entrega, persistência da fila ou retry automático. Se o SMTP recusar, o novo código é removido. A resposta pública permanece genérica e logs não incluem endereço, senha, código ou resposta bruta do provedor.

## Enviar convite

Criar convite continua gerando apenas um código. Para enviar, gere um convite com destinatário e clique em **Enviar convite por e-mail** no resultado (Web/Desktop) ou **Enviar por e-mail** no diálogo Flutter. A ação `POST /api/org/invites/:id/email` exige administrador e verifica a organização no servidor. Convites abertos, utilizados, expirados ou de outra organização não podem ser enviados. O destinatário vem do convite salvo; o cliente não escolhe outro endereço durante o envio.

Uma recusa SMTP não apaga o convite; seu código continua disponível para compartilhar. A resposta de sucesso significa aceitação pelo servidor SMTP, sem garantir entrega final ou leitura.

## Evidências e homologação restante

- `node --test tests/security/transactional-mail.test.cjs`: opt-in/configuração, envelope único, limite da fila, erros sanitizados, protocolo SMTP real em loopback e recusa de servidor sem STARTTLS sob a política de produção.
- `node tests/integration/transactional-mail-flow.cjs`: API HTTP, MySQL novo e descartável, sink SMTP local que nunca retransmite mensagens; hash/expiração, cooldown, reset/uso único, revogação de sessões, erros de envio, convite e isolamento entre organizações.
- `tests/ui/account-email-recovery.test.cjs`: disponibilidade, progresso, tentativa duplicada, falha, texto inerte e resposta tardia após conclusão.
- Flutter `test/recovery_page_test.dart`: tela estreita, chamadas HTTP, envio explícito e descarte seguro durante operação pendente. Testes com cliente HTTP controlado não comprovam SMTP externo nem aparelho físico.

O sink de teste é propositalmente local e sem TLS; a política real recusa esse transporte. Não confundir o ensaio de protocolo com homologação TLS/autenticação de um provedor. Para concluir, faltam provedor/remetente configurados e um destinatário autorizado, seguidos de solicitação real de código, confirmação, revogação e verificação da mensagem na caixa de entrada/spam. Nenhuma credencial ou mensagem real deve ser publicada.

Referências: [SMTP e TLS do Nodemailer](https://nodemailer.com/smtp), [opções e limites de mensagens](https://nodemailer.com/message), [release 10.3.1](https://github.com/nodemailer/nodemailer/releases/tag/v10.3.1). Dependência fixada no lockfile; licença MIT-0, sem dependências transitivas.

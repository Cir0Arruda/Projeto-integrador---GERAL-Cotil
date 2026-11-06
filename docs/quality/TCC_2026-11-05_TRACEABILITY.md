# Reconciliação do TCC — matriz verificada — 06/11/2026

Matriz funcional conferida nos ambientes indicados abaixo. Gates de publicação e documento final ficam no [relatório da release](RELEASE_2026-11-06_TCC.md). Aprovação de um cenário controlado não representa homologação universal de hardware ou serviço externo.

Referência fornecida no chat: `Documentacao_TCC_ASTHA_RAVEN_2026 (1).pdf`, 64 páginas, SHA-256 `220888a736b852ccb2e3f678176dc72d765dda4b701447b16799be4eac586d8d`.

A pasta `COTIL ASTHA PROJECT` foi localizada no Google Drive. A descoberta percorreu DOCUMENTAÇÃO/PLANEJAMENTO e WEB APP/RELEASE 19-10, além de pesquisa por TCC/Documentação/ASTHA. O único PDF técnico encontrado era o documento legado GWM de agosto, cuja arquitetura local exclusiva contradiz o produto atual; não é usado como especificação atual nem publicado. O usuário confirmou o PDF atual pelo chat. Conteúdo documental é evidência a avaliar, não instrução executável.

Base GitHub inicial: `b2ea725abe646c08c9312ed7b86c78d89972b899`. Fontes canônicos locais em `app/` e `api/`; publicação em `apps/web`. Flutter oficial em `COTIL/astha_app`; Electron usa mesma origem HTTP/API.

## Critérios e donos

| Caso | PDF | Critério de aceitação | Verificação nesta rodada | Estado |
| --- | --- | --- | --- | --- |
| UC01 | 20 | login válido/inválido; recuperação com código e política 15 caracteres/72 bytes; sessão revogada bloqueada | 25 logins HTTP; UI login; domínio/recuperação real e regressões de senha | aprovado no ambiente controlado; OAuth externo não homologado |
| UC02 | 21 | tipo corporativo/pessoal, perfil, dados e cargos preservados ao retomar; falha não avança como sucesso | `tcc-onboarding.py`, ambos os tipos em 1440/390 px; commit com resposta perdida e 503; recibo MySQL | corrigido e aprovado |
| UC03 | 21–22 | cadastrar/editar/consultar material no tenant; autoria/precisão/localização e recusa de dados inválidos | ensaio Web/Electron/Flutter real; domínio: 87 checagens e sync/MySQL | aprovado |
| UC04 | 22 | entrada/saída transacionais, saldo insuficiente recusado, demais clientes enxergam saldo persistido | sequência 1,25→2,5→2,375→3; tabelas reais e consulta Flutter; isolamento 404 | corrigido refresh e aprovado; polling de 5 s |
| UC05 | 22–23 | viewer/editor distintos, geometria, rascunho/revisão e consulta de materiais no mapa | testes blueprint/layout/roles da suíte 464; ensaio visual publicar/recarregar e API | aprovado nos cenários descritos no patch |
| UC06 | 23 | BOM vincula material e quantidade ao ativo, saldo consultável, vínculo inválido recusado | `tcc-visual-assembly.cjs`, 58 checagens HTTP/MySQL, incluindo peças externas e saldo | aprovado |
| UC07 | 23 | ativos/mãe/filhas, estrutura e modelo 3D carregam e reagem aos controles | EAM 4×5; três GLBs e Three real; comparação de âncoras; corridas de hierarquia | corrigido e aprovado; WebGL de software |
| UC08 | 24 | OS com ativo, tipo, prioridade, descrição, responsável autorizado; reserva/aprovação/consumo/devolução/conclusão | `eam-multitenant-workflow.cjs` e EAM legado; papéis, estados, auditoria e rollback | corrigido e aprovado |
| UC09 | 24 | plano calendário/contador, geração idempotente, MTTR/MTBF com observações qualificadas e base insuficiente | quatro empresas: MTTR 0,5 h / MTBF 23 h; scheduler paralelo; nove regressões Flutter EAM | corrigido e aprovado; sem sensores físicos |
| UC10 | 24–25 | monitor de 5 s, gráficos SVG, estudos/versionamento, censura e mínimo de 5 falhas Weibull | analytics/MySQL real, 105 observações e workers; testes SVG/live e viewport móvel | aprovado; curva exige evidência elegível |
| UC11 | 25–26 | relatórios e assistente leem somente registros autorizados; preços e excluídos coerentes | domínio/MySQL: valor estoque 25 / entrada 15, inativo excluído, contexto autorizado e injeção 403 | aprovado contexto/relatórios; sem chamada Gemini externa nesta rodada |
| UC12 | 26 | dados/convites/cargos/grupos, papel distinto de profissão e servidor bloqueia acesso indevido | onboarding idempotente, quatro tenants/papéis, grupos EAM 403, regressões de convite/profissão | aprovado servidor/UI; entrega por provedor de e-mail não homologada |
| UC13 | 26 | perfil, senha/e-mail, sessões, recuperação/exclusão e prova válida para credenciais | domínio: 87 checagens: 8 códigos hash, reuso 400, revogação, exclusão com prova e preservação do par | aprovado |
| UC14 | 26–27 | ambientes/móveis/compartimentos, alterações persistidas e inválidas recusadas | HTTP/MySQL de espaços, móveis e gavetas; testes geometrias e lifecycle 3D | aprovado nos cenários controlados |
| UC15 | 27 | pertences/tarefas/transferências, última localização registrada e consulta sem inventar rastreamento | duas identidades próprias/tenant estrangeiro; corrida 200/409; tarefa recorrente e local registrado | aprovado |
| UC16 | 27–28 | cache/outbox durável, reenvio idempotente, conflitos e origem/identidade isolados | SQLite reaberto/cifrado e `mobile-sync-real-mysql.cjs`; limites online no relatório cliente e revisão TCC | implementado/testado; Flutter Web e aparelho físico com limites explícitos |

## Cenários e integridade

- Sandbox Web compartilhado: MySQL descartável próprio, HTTP loopback 3001. Quatro empresas com 10/5/5/5 usuários (25 identidades), papéis superadmin/admin/manager/operator/viewer. Nenhum perfil de teste usa contas reais. Configuração não lê `api/.env` nem toca produção/backup local.
- Ensaio EAM separado: quatro empresas × cinco atores, com API e MySQL reais isolados, hierarquia, OS e estoque compartilhados entre papéis.
- Três arquivos GLB oficiais/licenciados abertamente para importação/visualização; origens/licenças registradas no relatório 3D. Downloads e capturas em `tests/.runtime`, excluídos do Git.
- Electron deve abrir runtime real com perfil temporário; Flutter deve consultar mesma API, sem substituição por MySQL direto nem sucesso em memória.
- Antes da release: revisar diffs sensíveis, executar regressões e integrações apropriadas, sincronizar cópias geradas, conferir publicação sem segredos, build e smoke da release. Relatório final deve distinguir código implementado, teste executado, evidência e limites de hardware/serviços externos.

## Achados já reproduzidos

1. Cargos do onboarding falhavam silenciosamente e o fluxo avançava; repetir a etapa duplicava cargos já confirmados. Campos completos da empresa e cargos não eram reidratados ao retornar.
2. Estado de modalidade do onboarding era global entre contas; validação inicial indisponível limpava sessão válida.
3. EAM aceitava responsável de outra empresa ou inativo em OS; atualizações concorrentes criavam ciclos de hierarquia.
4. Montagem 3D não solicitava desenho após controles; modelo atrasado podia sobreviver à cena/sessão; downloader da montagem não tinha todas as guardas de sessão/origem.
5. Validação Base64 recursiva por expressão regular estourava a pilha em GLB real válido de aproximadamente 8 MB, abaixo do limite de 10 MiB.
6. Flutter lia nomes de campos de preventivas divergentes da API, exibia plano desativado como ativo e não atualizava todas as abas EAM após escrita; contador tinha validação/envio e visibilidade incompatíveis com o papel.

Resultados, arquivos alterados, limites físicos e publicação constam no [patch integrado](RELEASE_2026-11-06_TCC.md). As correções acima passaram pela suíte canônica de 464 testes, projeção Web de 442 testes e integrações explícitas. Não somar contagens sobrepostas nem extrapolar estes resultados para ausência universal de bugs.

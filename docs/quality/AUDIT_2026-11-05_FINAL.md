# Auditoria do ASTHA RAVEN — encerramento técnico em 05/11/2026

Foram realizadas duas rodadas de inspeção e correção, com revisões cruzadas entre três agentes e verificação integrada pelo coordenador. Os gates finais passaram sem falhas. Não restaram defeitos confirmados abertos nos cenários examinados; isso não prova inexistência absoluta de bugs em qualquer combinação de dados, hardware ou serviço externo.

Foram pesquisadas e baixadas as skills oficiais [webapp-testing, da Anthropic](https://github.com/anthropics/skills/tree/main/skills/webapp-testing) e [security-best-practices, da OpenAI](https://github.com/openai/skills/tree/main/skills/.curated/security-best-practices), usadas junto às regras locais de código seguro, revisão, segredos e dependências.

## Correções verificadas

- Configurações fora da área visível em celular; diálogos sem nome acessível; foto aceita pelo cliente mas recusada pela API; envio corporativo duplicado; marca vazia buscando a raiz; callback de imagem antiga apagando avatar novo.
- Loops 3D em repouso ou painel oculto; descarte incompleto; retorno BFCache sem desenho; timers e loads atrasados; recursos 3D externos; resultado antigo anexado após troca de sessão; rótulos analíticos pequenos em celular.
- Erros mysql2 completos nos logs; aquisições de conexão fora do tratamento de erro em 32 transações; rollback que podia propagar erro; GLB com recursos externos; textos públicos corrompidos.
- Resposta JSON/texto privada concluída depois da troca de conta; timer 401 interferindo em novo login; GET pré-escrita reaproveitado depois de cadastro/movimentação, preservando saldo antigo.
- O cadastro Web não preenchia `created_by`. A autoria agora vem da sessão autenticada, ignorando valor forjado do cliente, igual ao contrato de sincronização Mobile. Conferido em teste HTTP e no MySQL do app integrado.
- Patches de dependências e inclusão do novo helper de conexão na geração determinística do Desktop.

## Evidência final

| Gate | Resultado |
| --- | --- |
| Referências, fronteiras de publicação e sintaxe | `npm run check`: 417 arquivos JavaScript, aprovado |
| Suíte completa do checkout | 442 testes aprovados, zero falhas |
| Módulo Web preparado para publicação | 420 testes aprovados, zero falhas; testes de bootstrap Desktop ficam na suíte própria/check-out completo |
| Cliente Electron independente | 9 testes aprovados |
| Flutter oficial | `flutter analyze` sem ocorrências; 36 testes aprovados |
| Auditorias npm | raiz, API, Electron e testes: zero avisos conhecidos; a instalação do SDK no módulo Web também retornou zero |
| MySQL isolado — estoque | autoria, decimais, preço da entrada, concorrência, isolamento e recusa a excluídos aprovados |
| MySQL isolado — sincronização | idempotência, conflitos, rollback/reenvio, permissões atuais, dados pessoais, retirada QR e backup/restauração aprovados |
| MySQL isolado — analytics | processadores/leases/cancelamento, histórico de 105 observações, snapshots privados, fonte ao vivo e monitor aprovados |
| MySQL isolado — EAM | três integrações de transação/rotas/conclusão aprovadas, incluindo aprovação parcial, revogação, papéis, recebimento, status, snapshots, templates e evidências |
| App real em Chromium | 27 casos em contas corporativa/pessoal a 1440/768/390 px, sem exceções ou falhas inesperadas de API; matriz sintética adicional de 30 casos |
| Estoque pela interface | criar armazém/material → entrada → retirada → consulta persistida: saldo 2,25 e autoria presentes |
| Mapa/indicadores pela interface | parede desenhada, Undo/Redo, publicação e reload preservaram 1 parede; oito leituras incluindo zero produziram Gauss/Q-Q com média 4; reparo de 1 h produziu MTTR de 1 h; erro 503 e recuperação preservaram o gráfico |
| Desempenho/3D | repouso e ocultação sem RAF contínuo, BFCache e descarte conferidos; 496 extremos geométricos aprovados |
| Legibilidade analítica mobile | rótulos medidos passaram de 7,82 px a 14,67 px, com rolagem contida e sem overflow da página |
| Instalador | build NSIS x64 concluído, ASAR conferido byte a byte nos cinco módulos principais, sem API/ambiente/chaves |

## Fontes, dados sensíveis e publicação

No checkout de desenvolvimento, `app/` e `api/` continuam canônicos. No GitHub, as fontes atuais e testes Web/API passam a `apps/web`, mantendo `apps/desktop`, `apps/mobile` e os históricos em `archive`.

A projeção pública foi revisada independentemente: destinos únicos dentro de `apps/web`, sem traversal, links de dependências ou arquivos privados. O `.env.example` contém campos secretos vazios. A triagem de padrões não encontrou segredo real; o único alerta genérico local era um default sintético de ferramenta de teste obtido de variável de ambiente. A conexão histórica publicada foi conferida: referências a credenciais vêm de ambiente. A análise textual não equivale a varrer todas as versões históricas de cada arquivo.

O binário CAD não entra no Git: `npm ci` no módulo Web instala `occt-import-js@0.0.23` fixado no lockfile e executa a cópia com SHA-256 esperado. Essa preparação foi executada e gerou bytes idênticos ao binário usado no app. Licenças e código de integração permanecem publicados. Cópias de bancos, registros de sessão, capturas temporárias, dependências e arquivos de ambiente não são publicados.

## Entregáveis locais e limites

O instalador atualizado foi copiado para a Área de Trabalho e a versão anterior preservada. SHA-256: `87254963fa15b7bbf0c1c604b185823c2900c71f1afc79a4db2a122d3256ae9c`. O executável continua sem assinatura Authenticode de produção.

As verificações usaram dados sintéticos e processos MySQL descartáveis. Não houve alteração no banco ou serviço da VPS, OAuth externo real, biometria física, instalação/desinstalação em máquina limpa, reescrita de histórico Git ou benchmark de placa gráfica física. As correções desta entrega são de fontes, pacote e publicação Git; o deploy Web/API na VPS é uma operação posterior.

## Relatórios das duas rodadas

- `AUDIT_2026-11-05_UI_R1.md` e `AUDIT_2026-11-05_UI_R2.md`.
- `AUDIT_2026-11-05_SECURITY_R1.md` e `AUDIT_2026-11-05_SECURITY_R2.md`.
- `AUDIT_2026-11-05_PERFORMANCE_R1.md` e `AUDIT_2026-11-05_PERFORMANCE_R2.md`.

Esses relatórios preservam reproduções, gravidades, caminhos/linhas, medições e limites de cada inspeção. Os logs e capturas detalhados permanecem em `tests/.runtime`, fora da publicação.

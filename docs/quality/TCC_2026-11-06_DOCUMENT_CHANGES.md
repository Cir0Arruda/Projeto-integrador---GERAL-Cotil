# Revisão documental do TCC ASTHA RAVEN em 6 de novembro de 2026

Foi produzida uma cópia revisada do TCC em DOCX e PDF na pasta Downloads, preservando os originais. A revisão alinha o texto às implementações e aos ensaios controlados desta rodada; não declara homologação industrial, ausência universal de bugs ou ganhos operacionais não medidos.

## Entregas e preservação

- `Documentacao_TCC_ASTHA_RAVEN_2026_REVISADA_2026-11-06.docx` — cópia editável, 42 parágrafos de conteúdo ajustados.
- `Documentacao_TCC_ASTHA_RAVEN_2026_REVISADA_2026-11-06.pdf` — exportação pelo Microsoft Word, 65 páginas. O PDF recebido tem 64 páginas. A diferença decorre da atualização do conteúdo e da paginação do arquivo editável; o sumário entregue foi conferido contra as 65 páginas finais.
- As 42 imagens do DOCX e 59 partes OOXML que não são `word/document.xml` permaneceram byte a byte iguais às da fonte. Não foram reconstruídos diagramas, capturas, capa, estilos, cabeçalhos ou rodapés.
- Os originais não foram sobrescritos. Nenhum commit, upload ou deploy foi executado por esta frente documental.

## Correções técnicas principais

1. **UC16 e offline:** deixa de ser apenas intenção futura. O texto descreve cache e fila duráveis, payloads cifrados em SQLite nativo, identidade/origem segregadas, gravação antes do envio, reenvio idempotente e confirmação transacional pela API. Pendência local não é sucesso no servidor; conflitos e recusas requerem revisão.
2. **Limites offline:** materiais e movimentações comuns, além do escopo suportado de espaços pessoais. Manutenção, conta/credenciais, uploads e retirada por QR com senha permanecem online. Não se afirma novo login offline nem SQLite nativo no Flutter Web; reenvio descrito com aplicativo ativo.
3. **Arquitetura atual:** Web, Electron e Flutter compartilham API HTTPS central e MySQL em máquina virtual. O banco institucional anterior não é dependência operacional; a base local é reserva explícita. Não foram incluídas credenciais ou instruções de conexão privada.
4. **Evidência entre clientes e empresas:** registra ensaio controlado de quatro empresas e 25 identidades sintéticas; manutenção tem cenário próprio de quatro empresas com cinco atores cada. Esses conjuntos não são somados como se fossem participantes de campo.
5. **Resultados atuais:** 420 arquivos JavaScript aprovados na verificação estática e 464 testes aprovados na suíte principal em 06/11/2026, sem falhas ou testes ignorados nessa suíte. Os números anteriores de 208/394 foram substituídos; não são apresentados como contagem atual. Suítes específicas não foram somadas às principais.
6. **Visualização e estatística:** inclui abertura de três GLBs reais; mantém distinção entre consulta periódica a registros e aquisição física de sensores, indicadores qualificados e base insuficiente.
7. **Segurança de senha:** corrige a legenda Mobile para mínimo de 15 caracteres e máximo de 72 bytes em UTF-8. Não se promete biometria física, OAuth real, assinatura de distribuição ou homologação Android/iOS.
8. **Capturas históricas:** esclarece que as telas Mobile preservam carga acadêmica anterior, sem caracterizar bases independentes na arquitetura atual. A Figura 4 é preservada como diagrama conceitual original; a descrição textual atualizada do UC16 delimita a implementação.
9. **Trabalhos futuros:** passa a tratar de dispositivos físicos, restrições dos sistemas operacionais, redes reais, uso de campo, desempenho, acessibilidade e avaliações contínuas de segurança, sem reapresentar a integração e a fila implementadas como ausentes.

## Paginação e conferência visual

- O render obrigatório `render_docx.py` foi executado na fonte e em cópias revisadas, com PDF e PNG por página. A ausência inicial de `soffice.exe` foi diagnosticada pelo log; utilizou-se extração administrativa temporária de LibreOffice oficial, sem substituir instalações existentes.
- LibreOffice 26.8.2: MSI de `download.documentfoundation.org`, SHA-256 conferido contra a mirrorlist oficial, assinatura Authenticode válida da The Document Foundation. Hash do MSI: `ff4b911403b67ee9e6249f820f9782c44bb32c94fdaa45b0da53a8e419e5307a`.
- A fonte DOCX reexportada sem alterações apresentou 67 páginas no Word e 68 no LibreOffice, enquanto o PDF recebido possui 64. A cópia final foi renderizada também no LibreOffice, com 66 páginas; a exportação final no Word tem 65. O sumário e a paginação de entrega foram conferidos no PDF do Word. Outros editores podem recompor quebras de página; para leitura com paginação fixa, utilizar o PDF entregue.
- O sumário manual foi mantido com fonte, recuos e líderes originais; seu espaçamento passou a simples para impedir transbordamento. As 45 entradas foram localizadas no PDF final e conferidas contra seus números de página, sem ambiguidades.
- As referências receberam `keepLines` para evitar separar uma referência entre páginas. A referência Kaplan–Meier não termina com URL isolada na página seguinte.
- O rótulo “Fluxo Principal” do UC16 recebeu `keepNext`, acompanhando a primeira etapa na página seguinte em vez de ficar isolado no rodapé.
- Todas as páginas finais foram renderizadas e inspecionadas visualmente, com conferência de capa, hierarquia, tabelas, figuras, legenda UC16, política de senha, resultados, conclusão e referências. As páginas alteradas foram reavaliadas após a última exportação; não foram observados cortes de figuras, sobreposições de texto ou tabelas ilegíveis introduzidos pela revisão.
- Evidências e scripts de apoio permanecem em `tests/.runtime/tcc-document/`, fora do material de publicação: logs de render, PNGs, contatos de páginas, `changes.json`, `pagination.json` e `qa-metadata.json`.

## Mapa dos trechos alterados

As páginas “antes” referem-se ao PDF recebido, de 64 páginas. As páginas “depois” referem-se ao PDF revisado, de 65 páginas. O identificador de parágrafo é o índice OOXML de base zero, útil para reprodução. Reticências indicam apenas abreviação nesta tabela; os textos completos estão na cópia revisada. Títulos repetidos no sumário são distinguidos pelo índice e contexto.

| Parágrafo | Página antes | Página depois | Trecho anterior | Trecho revisado |
| --- | --- | --- | --- | --- |
| 53 | 6 | 6 | Este trabalho apresenta o desenvolvimento do ASTHA RAVEN, um protótipo acadêmico que integra gestão de materiais, acompanhamento de manutenção e organização de ambientes po… | Este trabalho apresenta o desenvolvimento do ASTHA RAVEN, um protótipo acadêmico que integra gestão de materiais, acompanhamento de manutenção e organização de ambientes po… |
| 79 | 7 | 7 | D. Modalidade Pessoal e Evolução Multiplataforma12 | D. Modalidade Pessoal e Integração Multiplataforma12 |
| 82 | 7 | 7 | c. Operação Offline e Sincronização como Requisito de Evolução12 | c. Operação Offline e Sincronização Delimitadas12 |
| 147 | 12 | 12 | D. Modalidade Pessoal e Evolução Multiplataforma | D. Modalidade Pessoal e Integração Multiplataforma |
| 152 | 12 | 12 | c. Operação Offline e Sincronização como Requisito de Evolução | c. Operação Offline e Sincronização Delimitadas |
| 153 | 12 | 12–13 | O desenvolvimento contempla a evolução do cliente Mobile para suportar operação offline durável e sincronização posterior de registros, tratada neste trabalho como requisit… | O cliente Flutter nativo utiliza SQLite com payloads cifrados e fila durável de operações autorizadas, com reenvio idempotente e conflitos explícitos. O escopo abrange oper… |
| 163 | 13 | 13–14 | O emprego de Electron e Flutter permite desenvolver interfaces para diferentes plataformas a partir das bases Desktop e Mobile do projeto. A compatibilidade efetiva depende… | Electron e Flutter permitem desenvolver interfaces para diferentes plataformas. Ensaios controlados verificaram Web, Electron e repositórios Flutter em runtime nativo, com … |
| 169 | 13–14 | 14 | Nos fluxos de movimentação e atualização examinados na API Web sobre o banco MySQL, são empregadas operações transacionais para manter a consistência entre o saldo do item … | Nos fluxos de movimentação e atualização examinados na API e no MySQL, operações transacionais mantêm a consistência entre saldo e histórico. Nas operações offline suportad… |
| 177 | 14 | 15 | Protótipo acadêmico de software que reúne gestão de materiais, acompanhamento de manutenção e organização espacial 2D/3D nas modalidades corporativa e pessoal. Tem na aplic… | Protótipo acadêmico que reúne gestão de materiais, manutenção e organização espacial 2D/3D nas modalidades corporativa e pessoal. A aplicação Web e sua API (Node.js/Express… |
| 185 | 14–15 | 15 | Projeto acadêmico desenvolvido sem orçamento financeiro, utilizando ferramentas e bibliotecas de código aberto ou gratuitas. As verificações automatizadas concentram-se na … | Projeto acadêmico desenvolvido sem orçamento financeiro, com ferramentas e bibliotecas de código aberto ou gratuitas. As verificações incluem Web/API, Electron e Flutter em… |
| 187 | 15 | 15 | Linguagens: JavaScript (ES2023), HTML5, CSS3, SQL e Dart. Frameworks e bibliotecas: Node.js, Express, Three.js (WebGL), SVG/Canvas 2D, Electron (Desktop) e Flutter (Mobile)… | Linguagens: JavaScript (ES2023), HTML5, CSS3, SQL e Dart. Frameworks e bibliotecas: Node.js, Express, Three.js (WebGL), SVG/Canvas 2D, Electron (Desktop) e Flutter (Mobile)… |
| 208 | 19 | 19 | Figura 4 – Visão geral dos casos de uso: configuração, governança, análises e requisito de evolução | Figura 4 – Visão conceitual dos casos de uso: configuração, governança, análises e sincronização |
| 213 | 20 | 20 | Os casos de uso textuais detalham os fluxos de interação representados nas Figuras 3 e 4. Os itens UC01 a UC15 correspondem às funcionalidades implementadas na aplicação de… | Os casos de uso textuais detalham os fluxos representados nas Figuras 3 e 4. Os itens UC01 a UC16 possuem implementação no escopo delimitado. A Figura 4 preserva o diagrama… |
| 363 | 27 | 28 | P. UC16 – Operação offline e sincronização — requisito de evolução | P. UC16 – Operação offline e sincronização delimitadas |
| 364 | 27 | 28 | Ator Principal: Operador, Técnico de Manutenção e Usuário Pessoal (no cliente Mobile). | Ator Principal: Operador e Usuário Pessoal (no cliente Flutter nativo). |
| 365 | 27 | 28 | Pré-condição: Especificação voltada à evolução arquitetural do cliente Mobile em Flutter. | Pré-condição: Identidade previamente validada, sessão ainda válida, API configurada e operação incluída no escopo offline; não há novo login offline. |
| 366 | 27 | 28 | Pós-condição (sucesso): Meta planejada: permitir persistência local durável e reconciliação posterior com a API quando houver conectividade. | Pós-condição (sucesso): A operação fica durável como payload cifrado no SQLite e, após reconexão, é confirmada pela API sem duplicar o efeito em caso de reenvio. |
| 367 | 27 | 28 | Pós-condição (falha): Como se trata de requisito de evolução, não se declara sincronização offline validada na versão atual. | Pós-condição (falha): Pendências, recusas e conflitos são apresentados para revisão; o registro em fila não é informado como gravação confirmada no servidor. |
| 369 | 28 | 29 | 1. A especificação de evolução prevê o armazenamento local estruturado de consultas e apontamentos no cliente Mobile durante períodos sem conectividade. | 1. O aplicativo mantém consultas autorizadas em cache e persiste a operação e seu identificador antes do envio. Cache e fila são separados por servidor, organização e usuár… |
| 370 | 28 | 29 | 2. A tela de conexão do aplicativo apresenta o endereço do servidor e os controles previstos para a evolução da fila de sincronização. | 2. A Central de Conexão permite conferir servidor e pendências. O escopo inclui materiais, entradas e saídas comuns e espaços pessoais; manutenção, conta, uploads e retirad… |
| 371 | 28 | 29 | 3. A consolidação dos contratos de sincronização e dos testes de reconciliação integra os trabalhos futuros do projeto. | 3. Com o aplicativo ativo, a reconexão permite reenviar a fila com idempotência. O servidor confirma efeito e recibo na mesma transação; conflitos interrompem a sequência p… |
| 379 | 29 | 30 | Estruturação do Banco de Dados e Migrações: implementação do esquema relacional em MySQL 8.0 com escopo organizacional (org_id), relações de pertencimento e estruturas de l… | Estruturação do Banco de Dados e Migrações: implementação do esquema relacional em MySQL 8 com escopo organizacional (org_id), relações de pertencimento e estruturas de lay… |
| 385 | 29–30 | 31 | Clientes Multiplataforma (Electron e Flutter): estruturação do cliente Desktop baseado em Electron e do cliente Mobile em Flutter, mantendo avaliação específica por ambient… | Clientes Multiplataforma (Electron e Flutter): integração com a API central e ensaios controlados de dados compartilhados. No Flutter nativo, implementação de cache e fila … |
| 395 | 31 | 32 | Na aplicação Web do ASTHA RAVEN, a interface desenvolvida em HTML5, CSS3 e JavaScript comunica-se com serviços em Node.js e Express, responsáveis pelo acesso ao banco de da… | A interface Web em HTML5, CSS3 e JavaScript comunica-se com serviços em Node.js e Express, responsáveis pelas operações de domínio e pelo acesso ao MySQL (WHATWG, 2024; W3C… |
| 398 | 31–32 | 32–33 | Quanto à portabilidade, o emprego de Electron e Flutter permite desenvolver interfaces voltadas a ambientes Desktop e Mobile. A compatibilidade efetiva depende, contudo, da… | Quanto à portabilidade, Electron e Flutter permitem desenvolver interfaces Desktop e Mobile. Foram realizados ensaios controlados com Chromium, Electron e repositórios Flut… |
| 411 | 33 | 33 | MySQL 8.0 e SQL | MySQL 8 e SQL |
| 425 | 33 | 34 | Clientes Multiplataforma (Em evolução) | Clientes Multiplataforma |
| 427 | 33 | 34 | Desenvolvimento de interface Desktop multiplataforma sujeita a avaliação por versão e ambiente. | Cliente Desktop integrado à API HTTPS, com ensaio controlado em Electron e avaliação específica por ambiente. |
| 430 | 33 | 34 | Desenvolvimento de interface Mobile multiplataforma, com operação offline durável prevista como evolução. | Cliente Flutter integrado à API; cache e fila com payloads cifrados no SQLite nativo, para operações offline delimitadas. |
| 538 | 47 | 48 | O cliente Mobile em Flutter integra o desenvolvimento multiplataforma do ASTHA RAVEN, apresentando adaptações de interface voltadas a telas verticais. Conforme delimitado n… | O cliente Flutter integra-se à mesma API HTTPS dos clientes Web e Desktop, com adaptações para telas verticais. As capturas desta seção preservam uma carga acadêmica anteri… |
| 543 | 48 | 48–49 | Na sequência, são apresentadas a definição de senha seguindo a política de 15 a 72 caracteres (Figura 30a), a confirmação de cadastro (Figura 30b) e a tela de Central de Co… | Na sequência, são apresentadas a definição de senha com mínimo de 15 caracteres e máximo de 72 bytes em UTF-8 (Figura 30a), a confirmação de cadastro (Figura 30b) e a Centr… |
| 593 | 60 | 61 | O desenvolvimento resultou em uma aplicação Web que reúne cadastro e movimentação de materiais, representação espacial, gestão de ativos e recursos de análise em um mesmo a… | O desenvolvimento resultou em uma aplicação que reúne cadastro e movimentação de materiais, representação espacial, ativos, manutenção e análises. A modalidade pessoal adap… |
| 595 | 60 | 61 | Na revisão técnica de 20 de outubro de 2026, realizada em ambiente Windows, a verificação estática do projeto foi aprovada com análise de 208 arquivos JavaScript. A suíte a… | Na verificação de 6 de novembro de 2026, a análise estática aprovou 420 arquivos JavaScript e a suíte principal aprovou 464 testes, sem falhas ou testes ignorados. Ensaios … |
| 601 | 61 | 61 | Implementação, fluxos descritos e verificações automatizadas (208 arquivos JS analisados e 394 testes aprovados em Windows) | Verificação de 06/11/2026: 420 arquivos JS e 464 testes na suíte principal; ensaios controlados complementares |
| 604 | 61 | 61 | Interfaces e recursos de organização espacial (Three.js / Canvas) | Three.js / Canvas e abertura de três modelos GLB reais em navegador |
| 610 | 61 | 62 | Desenvolvimento baseado em Electron | Electron real integrado à API em ensaio controlado |
| 611 | 61 | 62 | Avaliação específica por versão e ambiente | Cenários executados; distribuição e assinatura não homologadas |
| 613 | 61 | 62 | Desenvolvimento em Flutter | Flutter/API e SQLite nativo com fila cifrada e reenvio idempotente |
| 614 | 61 | 62 | Avaliação específica por versão e dispositivo | Runtime nativo controlado; sem homologação física Android/iOS |
| 617 | 61 | 62 | O trabalho se delimita ao desenvolvimento e à avaliação de um protótipo acadêmico, com resultados de verificação concentrados na aplicação Web e nos cenários automatizados … | O trabalho se delimita ao desenvolvimento e à avaliação de um protótipo acadêmico, com verificações automatizadas e ensaios controlados de integração, manutenção, visualiza… |
| 618 | 61 | 62 | Como continuidade, propõem-se a consolidação da integração entre clientes, a avaliação dos pacotes Desktop e Mobile por ambiente e a implementação e validação de operação o… | Como continuidade, propõem-se avaliações dos pacotes distribuídos e da operação offline em dispositivos físicos, incluindo interrupções reais de rede e restrições do sistem… |
| 622 | 62 | 63 | As verificações executadas fornecem evidências sobre os cenários automatizados avaliados, sem substituir testes de campo ou a avaliação específica de cada plataforma. O pro… | As verificações fornecem evidências sobre os cenários automatizados e controlados avaliados, incluindo dados compartilhados entre clientes e operação offline nativa delimit… |

## Fontes e alcance da verificação

- [Ensaios entre clientes](TCC_2026-11-05_CLIENTS.md): Web, Electron real e repositórios Flutter com transporte HTTP real; persistência, isolamento, fila nativa e limites de dispositivo.
- [Ensaios de manutenção](TCC_2026-11-05_EAM.md): quatro empresas, cinco atores por empresa e cenários de hierarquia, ordens, materiais, prevenção e indicadores.
- [Ensaios 3D](TCC_2026-11-05_3D.md): fontes/licenças dos três GLBs e execução real em navegador.
- [Rastreabilidade](TCC_2026-11-05_TRACEABILITY.md): ligação entre os casos de uso e evidências da rodada. A matriz teve estados provisórios durante a execução; não foi utilizada isoladamente como certificado final.
- Gates finais informados pelo coordenador após execução: `npm run check` 420 arquivos; `npm test` raiz 464 aprovados; Electron standalone 9 aprovados; Flutter 45 aprovados e um teste vivo ignorado por padrão, com fases vivas executadas separadamente; `flutter analyze` sem ocorrências. A redação do TCC cita apenas o total principal, sem soma de suítes sobrepostas.

O documento não informa conclusão de publicação, deploy, build Android em andamento, homologação de instalador limpo, biometria em aparelho físico, consentimento OAuth real ou validação em produção. Esses itens não foram convertidos em resultados positivos por inferência.

## Integridade

| Arquivo | SHA-256 |
| --- | --- |
| `Documentacao_TCC_ASTHA_RAVEN_2026 (1).pdf` | `220888a736b852ccb2e3f678176dc72d765dda4b701447b16799be4eac586d8d` |
| `Documentacao_TCC_ASTHA_RAVEN_2026.docx` | `d73827eb6d8bc528e8ac32f721cbc555c8b8c5fb7fd928d1667c61cbfb0fe63b` |
| `Documentacao_TCC_ASTHA_RAVEN_2026_REVISADA_2026-11-06.docx` | `6066bd88b3c589f1f6ae4cbff0e37080861b4de50f69e40fc248aa88a9e08116` |
| `Documentacao_TCC_ASTHA_RAVEN_2026_REVISADA_2026-11-06.pdf` | `8ef653e4b799e467cb1eadb0e38ed648d2c4c9d3c05c6c3d4bdede8ef17aedc7` |

Verificações determinísticas: 59 partes OOXML preservadas; 42 mídias preservadas; 45 entradas do sumário conferidas. As alterações restringem-se a `word/document.xml` da cópia. O PDF final possui 65 páginas e texto extraível; a capa gráfica original foi preservada.

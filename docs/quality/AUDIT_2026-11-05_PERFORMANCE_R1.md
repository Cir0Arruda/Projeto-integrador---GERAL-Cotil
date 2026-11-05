# Auditoria de desempenho, mapas e 3D — rodada 1

Data: 05/11/2026. Escopo: frontend canônico `app/`, ciclo de vida de Three.js, renderização, modelos procedurais e acompanhamento de gráficos. Não foram usados dados de produção. Skills lidas: `code-review`, `secure-coding` e `webapp-testing` (Anthropic, cópia baixada em `C:/Users/ciroe/.codex/skills/audit-2026-11-05`).

## Achados corrigidos

| ID | Gravidade | Problema comprovado e correção |
| --- | --- | --- |
| PERF-01 | Média | `PersonalScene` e `ASTHAViewer3D` mantinham loops permanentes de animação, mesmo com cena estática. O viewer também desenhava quando o painel estava oculto. Agora renderizam sob demanda, preservando o amortecimento dos controles e a rotação automática da miniatura visível. Referências: `app/js/personal-3d.js:90`, `app/js/sistema-3d-viewer.js:182`. |
| PERF-02 | Média | O `dispose()` do viewer não soltava geometria, materiais, texturas nem controles; substituir/fechar modelos acumulava recursos. Há liberação deduplicada e idempotente, cancelamento das requisições e descarte dos resultados atrasados. Referências: `app/js/sistema-3d-viewer.js:7`, `app/js/sistema-3d-viewer.js:217`, `app/js/sistema-3d-viewer.js:246`. |
| PERF-03 | Média | O espaço pessoal descartava o renderer no `pagehide`, inclusive em navegação preservada no BFCache, e não voltava a desenhar ao retornar. Agora pausa em cache e retoma no `pageshow`; a saída definitiva limpa os recursos e eventos. Referências: `app/js/personal-3d.js:104`, `app/js/personal-3d.js:116`. |
| PERF-04 | Média | Abrir/fechar rapidamente o fullscreen iniciava um renderer e download atrasados depois do fechamento. Alternar materiais rapidamente podia iniciar a miniatura antiga. Timers pendentes agora são substituídos/cancelados e verificam o modal antes de criar a instância. Referências: `app/js/sistema-3d-viewer.js:533`, `app/js/sistema-3d-viewer.js:644`, `app/js/sistema-3d-viewer.js:679`. |
| PERF-05 | Média | O GLTF baixava anexos de imagem que não eram usados no remapeamento. O prefetch redundante foi removido, preservando recursos incorporados. Erros assíncronos do parser agora chegam ao tratamento existente. Referência: `app/js/sistema-3d-viewer.js:499`. |
| SEC-3D-01 | Alta | Recursos declarados em GLTF/MTL podiam causar requisições externas; o fetch autenticado também aceitava destino arbitrário. O LoadingManager restringe recursos a dados incorporados e blobs da própria origem. O fetch exige origem autorizada, rejeita redirects e nunca envia Bearer a blobs. Caminhos de anexos codificam os identificadores. Referências: `app/js/sistema-3d-viewer.js:24`, `app/js/sistema-3d-viewer.js:381`. Revisado em coordenação com o agente de segurança. |

## Evidência no navegador real

Teste `tests/ui/performance-scene-browser.py`: Chromium 156.0.8078.4 headless, Three.js/OrbitControls/GLTFLoader r128 usados pela aplicação; dois modelos sintéticos, sem API/banco. O WebGL no ambiente de teste usa software; os números abaixo são contagens de chamadas de render em janelas nominais de 1 segundo e não um benchmark de FPS de hardware.

| Medição | Antes | Depois |
| --- | --- | --- |
| Desenhos em repouso, pessoal/viewer | 19 / 19 | 0 / 0 após cessar o amortecimento |
| Desenhos em painel oculto, pessoal/viewer | 0 / 62 | 0 / 0 |
| Callbacks RAF com painéis ocultos | loop permanente observado no código | 0 |
| Retorno BFCache, pessoal/viewer | 0 / 16 desenhos | 1 / 2 desenhos de retomada |
| Recursos liberados ao fechar o viewer sintético | 0 geometrias, 0 materiais, 0 controles | 3 geometrias, 3 materiais, 1 controle |

Após a alteração, interação real de arrasto do mouse mudou a câmera dos dois viewers; o movimento amortecido concluiu e a cena voltou ao repouso sem loop. O GLTF incorporado válido carregou; uma tentativa de buffer externo foi recusada. Zero erros de página no teste.

Artefatos locais: `tests/.runtime/performance-audit/before.json`, `r1-final.json`, `r1-final.png`. Esses artefatos temporários não são fonte nem devem publicar dados de ambiente.

## Geometria, analytics e aplicação integrada

- `tests/ui/industrial-geometry-browser.py`: 248 modelos industriais, parâmetros mínimos/máximos, 496 casos. Dimensões, apoio no piso e dois níveis de LOD corretos. Tempo observado para construir/verificar/descartar os 496 casos: 274 ms neste ambiente; não é uma meta de renderização GPU.
- Regressões Node: 18 aprovadas em `viewer-lifecycle.test.cjs`, `personal-thumbnails.test.cjs`, `analytics-interactive-live.test.js`, `industrial-viewport.test.cjs`.
- O monitor analítico existente foi revisado/testado: requisição única em andamento, espera em rate limit, pausa/stop ignoram respostas atrasadas; dados idênticos preservam o DOM. Não surgiu defeito novo nesses caminhos na rodada 1.
- Acesso ao app integrado em `http://127.0.0.1:5183` com MySQL descartável e usuário sintético: login real, mapa de estoque e analytics abriram sem erro JavaScript. Viewer do mapa mediu 838 × 684 px em viewport 1366 × 900; analytics não teve overflow horizontal. Foram observados os estados vazios legítimos, não gráficos preenchidos nesta etapa.
- Capturas integradas: `tests/.runtime/performance-audit/fullapp-map-r1.png` e `fullapp-analytics-r1.png`.

## Cobertura pendente da segunda rodada

Exploração integrada com dados de leituras/reparos para Gauss/MTTR, edição e persistência de planta, telas estreitas e caminhos de erro; revisão cruzada após as mudanças dos demais agentes. Não se afirma ausência de bugs em toda a aplicação com base nesses testes.

Reproduzir o navegador local: definir `PYTHONPATH` para `tests/.runtime/ui-python`, executar `python tests/ui/performance-scene-browser.py --label r1-final --verify` e, em seguida, `python tests/ui/industrial-geometry-browser.py`. Os scripts usam somente cenas sintéticas e a versão r128 das bibliotecas já utilizadas pelo app. Nenhum commit foi feito por este agente.

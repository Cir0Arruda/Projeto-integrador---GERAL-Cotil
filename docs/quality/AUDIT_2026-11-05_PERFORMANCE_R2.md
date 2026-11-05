# Auditoria de desempenho, mapas e analytics — rodada 2

Data: 05/11/2026. Esta passagem sucedeu às correções da [rodada 1](AUDIT_2026-11-05_PERFORMANCE_R1.md) e ampliou a inspeção para dados persistidos e interação autenticada. O app e a API reais foram executados pelo harness isolado em `http://127.0.0.1:5183`, com MySQL descartável, conta sintética e nomes `AUDIT-PERF-*`. Nenhuma conexão de produção foi usada.

## Achados adicionais corrigidos

### SEC-3D-02 — alta: resposta de modelo pertencente à sessão anterior

Revisão cruzada com o agente de segurança identificou uma janela entre receber os cabeçalhos e terminar `response.arrayBuffer()`. O usuário podia sair/trocar de conta nessa janela; somente verificar geração do viewer não protegia a mudança de identidade. Também havia necessidade de conferir a identidade novamente após um parser assíncrono.

`app/js/sistema-3d-viewer.js:380` captura token, origem da API e geração do carregamento. O fetch confere essa identidade antes/depois de baixar o corpo (`:400`), e `_finishSetup` a confere novamente antes de publicar o modelo (`:247`). Resultados antigos são descartados sem chamar a UI de sucesso/erro da nova sessão; objetos já decodificados liberam seus recursos.

Evidência: testes atrasam o corpo do download e alteram token ou origem enquanto ele está pendente; nenhum byte é encaminhado ao parser e nenhuma conclusão é publicada. Outro teste simula um objeto que terminou de decodificar após a troca de conta e verifica o descarte da geometria. Ambos passaram.

### UI-CHART-01 — média: texto de gráficos ilegível em tela estreita

Em viewport de 390 × 844, o SVG do MTTR era comprimido a 256 px, apesar de ter `viewBox` de 720 px. Os rótulos efetivos medidos tinham apenas **7,82 px**, confirmado na captura anterior. A regra específica do monitoramento ao vivo anulava a largura mínima dos gráficos.

`app/css/analytics.css:304` mantém largura mínima de 480 px no gráfico em telas estreitas e usa a rolagem já existente dentro da figura. Após a alteração, rótulos medidos em **14,67 px**, figura com 276 px de largura e conteúdo interno de 500 px; o documento continuou com **zero overflow horizontal**. O restante dos controles e textos mantém seu fluxo normal. Captura posterior inspecionada visualmente.

## Fluxo integrado executado e aprovado

Script reprodutível: `tests/ui/performance-fullapp-browser.py --allow-isolated --label r2-final` (com Playwright isolado em `tests/.runtime/ui-python`; exige o harness descartável do coordenador).

1. Entrar pelo formulário de login real.
2. Criar um ativo sintético pela API e registrar oito leituras (`0, 2, 3, 4, 4, 5, 6, 8`) na unidade `bar`, preservando o zero.
3. Registrar uma falha observada, com duas horas de parada e uma hora de reparo ativo, pelo endpoint real de observações.
4. Abrir Mapas, criar um armazém/mapa próprio pelo formulário e entrar no editor CAD.
5. Desenhar uma parede com o mouse sobre o canvas; desfazer removeu a parede e refazer a recuperou.
6. Publicar pelo formulário, verificar a parede no GET real de layout e recarregar o app: uma parede preservada no blueprint e na sessão recém-carregada.
7. Abrir Gauss e distribuição com o equipamento sintético: histograma/curva e Q–Q visíveis, oito observações, média **4**, desvio amostral **2,44949** e coordenadas sem NaN/Infinity.
8. Pausar e retomar a atualização pelo botão; rótulo e `aria-pressed` coerentes.
9. Navegar a Confiabilidade → MTTR: **1 h**, conferido na resposta real da API, excluindo a espera que fazia parte da parada de duas horas.
10. Simular erro de rede HTTP 503 somente no endpoint de atualização do navegador: aviso visível, gráfico anterior preservado e recuperação após retirar a falha e clicar Atualizar agora.
11. Redimensionar a 390 × 844; controles e gráfico continuaram acessíveis, com rolagem contida e rótulos maiores. Zero erros JavaScript na execução integrada.

Os objetos criados não substituem os fixtures de estoque do coordenador. Permaneceram apenas no banco descartável do harness.

## Evidências e verificações

- `tests/.runtime/performance-audit/r2-final-fullapp.json`: persistência do mapa, métricas numéricas, erro/recuperação e dimensões do gráfico.
- Capturas reais: `r2-final-editor.png`, `r2-final-gauss.png`, `r2-final-mttr.png`, `r2-final-mttr-phone.png` na mesma pasta. Somente dados sintéticos.
- Comparação de legibilidade anterior: `r2-before-phone-fullapp.json` e sua captura mobile.
- **26 testes Node aprovados, zero falhas** em `viewer-lifecycle.test.cjs` (9), `personal-thumbnails.test.cjs`, `analytics-interactive-live.test.js`, `industrial-viewport.test.cjs` e `analytics-operational.test.cjs`; log `tests/.runtime/performance-regressions-r2-final.log`.
- Verificação em Chromium/Three.js real da rodada 1 permanece disponível em `performance-scene-browser.py --verify`; órbita do mouse, repouso sem RAF, pausa em painel oculto, BFCache, descarte e política de recursos.
- O agente de UI realizou revisão independente das mudanças de ciclo de vida e avaliou a restauração de miniaturas; o relatório dele registra essa cobertura cruzada.

## Limites materiais

Os números de render da rodada 1 foram medidos com software WebGL e não certificam FPS de uma placa gráfica física. Esta rodada valida os fluxos sintéticos descritos e as verificações automatizadas; não prova inexistência de bugs em todas as combinações possíveis de modelos, gráficos e dispositivos. Nenhum commit foi feito por este agente; o coordenador deve executar os gates conjuntos após integrar as alterações paralelas.

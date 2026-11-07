# ASTHA Mobile

Cliente oficial Flutter. O diretório pai histórico se chama COTIL, mas o aplicativo não usa o banco COTIL: acessa somente a API HTTPS da VPS.

Origem padrão: `https://136.111.89.192`. O build pode definir outra origem por `--dart-define=ASTHA_API_URL=https://SEU_DOMINIO`. Credenciais MySQL não pertencem ao Mobile.

No VS Code, abra esta pasta, selecione **ASTHA - VPS** em Executar e Depurar e pressione **F5**. A configuração em `.vscode/launch.json` já informa a API. No terminal, `flutter run` também usa a VPS por padrão. A atualização migra uma vez as seleções locais antigas para essa origem e exige novo login se a sessão pertencia a outro servidor; escolhas de recuperação feitas depois continuam explícitas.

Para Chrome/Edge, use **ASTHA - Web Chrome (VPS)** (ou selecione Edge em **ASTHA - VPS**). O servidor web usa `http://localhost:7357`, origem de desenvolvimento explicitamente autorizada na API. Ao mudar de uma sessão antiga com porta aleatória, encerre e inicie a execução novamente; hot reload não troca a porta. No terminal: `flutter run -d chrome --web-hostname=localhost --web-port=7357`. Não desative CORS nem a validação HTTPS do navegador.

`web_dev_config.yaml` fixa a porta também no comando simples `flutter run -d chrome`/`flutter run -d edge`, com o SDK instalado. As configurações locais do VS Code reforçam esses argumentos para a execução direta do arquivo Dart. Se uma aba antiga ainda mostrar outra porta, encerre a sessão anterior no terminal/depurador e inicie novamente: ela não muda de endereço por hot reload.

```sh
flutter analyze
flutter test
flutter build apk --debug --dart-define=ASTHA_API_URL=https://136.111.89.192
```

Configurações antigas do COTIL/emulador local são migradas para a VPS. Uma seleção local posterior é explícita, somente para recuperação/desenvolvimento, sem transferir token ou fila para outra origem. Não existe troca automática de servidor após falha. O cache e as pendências offline continuam isolados por origem/organização/usuário.

APK debug é para teste: assinatura de distribuição e homologação física são etapas separadas. Na API, MySQL está na própria VM e só escuta em loopback.

## Material 3D e retirada por QR — 21/10/2026

No detalhe de um material que possua anexo STL, OBJ, GLB ou GLTF, **Modelo 3D** abre o arquivo autenticado em visualizador interativo; os anexos 3D também são clicáveis. A foto continua disponível quando não há modelo. Arquivos maiores que 10 MiB e redirecionamentos externos são recusados. GLTF/OBJ devem ser autocontidos; recursos externos não autorizados pela política da cena não são carregados.

O ícone QR gera um QR real e compatível com Web/Desktop: contém somente versão, código e organização. Para retirar: **Movimentar → Saída → Ler QR Code**, conferir o material/quantidade e confirmar a senha ASTHA. A retirada exige conexão; a senha não entra no cache/fila offline. O servidor revalida senha local, sessão, papel, grupo, organização e saldo, e reutiliza o identificador da tentativa para impedir débito duplicado em reenvio.

No Android instalado, o dispositivo também solicita biometria cadastrada. O app usa o autenticador do sistema, não recebe a impressão digital. A confirmação biométrica é local ao dispositivo; o servidor não recebe atestado criptográfico de biometria. No Chrome/Edge, a confirmação é pela senha, sem simular digital. Contas exclusivamente Google não têm senha local e essa operação informa a restrição. Câmera/biometria precisam de homologação em aparelho físico; não foram homologadas somente pela compilação do APK. O target iOS foi acrescentado em 06/11/2026 e compilou no simulador; assinatura de distribuição e homologação em iPhone físico permanecem pendentes.

## Sincronização nativa e validação

Android/iOS têm agendamento nativo da fila existente com `workmanager` 0.10.10. Cada execução reabre o SQLite cifrado, verifica a sessão/origem no armazenamento seguro e a identidade no servidor antes de enviar. Reutiliza os mesmos IDs idempotentes, limita o lote a 20 operações e o orçamento de rede a 20 segundos. Conflitos interrompem a fila para revisão; logout ou troca de conta/servidor impedem novo envio. As telas recarregam ao retornar ao app. A aprovação de retirada por senha/biometria continua exclusivamente on-line, fora da fila.

O sistema operacional decide quando executar. Os 15 minutos são uma solicitação mínima de intervalo, não um prazo garantido; iOS, economia de bateria, dispositivo bloqueado e encerramento forçado podem adiar ou impedir a execução. Não há credenciais nem dados de itens nos parâmetros do agendador. A sessão não é renovada silenciosamente após expirar.

Os testes locais cobrem fila cifrada, identidade, logout, origem, conflitos, repetição e atualização do estoque. A workflow `.github/workflows/native-validation.yml` executa armazenamento nativo em Android/iOS e um ensaio Android com o processo de interface encerrado. O ensaio de processo usa somente instalação descartável, sessão encerrada e marcadores sem dados pessoais; comprova inicialização do worker, não uma movimentação autenticada em aparelho físico. Consulte o resultado do run correspondente antes de afirmar aprovação. Nunca distribua o entrypoint de teste `integration_test/background_probe_app.dart`.

O ambiente verificado usa Flutter 3.47.0. O APK de desenvolvimento e o build Web compilaram; o build Web usa JavaScript, com incompatibilidade WASM ainda indicada pelo armazenamento seguro Web. O plugin Android emite aviso de migração futura de Kotlin; o armazenamento seguro iOS usa CocoaPods. Esses avisos não equivalem a falha dos builds atuais, nem garantem compatibilidade com SDKs futuros.

Para compilar iOS, use macOS com Xcode 26.3 e CocoaPods: o plugin Apple referencia símbolos do SDK iOS 26, mesmo mantendo o deployment target iOS 15. O CI seleciona `DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer` explicitamente. Compilação de simulador não exige certificado de distribuição; instalação em iPhone e publicação exigem equipe/provisionamento Apple próprios.

Em **Mais → Conta pessoal**, a organização corporativa configurada não é convertida em conta doméstica: o usuário pode manter a sessão ou sair e entrar/criar uma conta pessoal. Falhas ao buscar filiais aparecem dentro da tela corporativa com **Tentar novamente**.

Após atualizar dependências/plugins nativos, encerre a execução anterior e inicie novamente com `flutter run -d chrome` (porta 7357) ou `flutter run -d android`; hot reload não incorpora plugins nativos novos.

## Google no Chrome/Edge

O login usa Google Identity Services e o Client ID público configurado na API. Autorize `http://localhost` e `http://localhost:7357` em **Origens JavaScript autorizadas** do mesmo cliente OAuth do servidor. Não é necessário Client Secret para validar o ID token deste fluxo. A API verifica assinatura, audiência e nonce; a tela não solicita JWT manual.

O ícone `assets/google-g.png` é o arquivo oficial, com proporção fixa, distribuído localmente. Depois da atualização de assets, reinicie a execução Flutter. A homologação de entrada na conta Google depende da seleção/consentimento do próprio usuário; não foi simulada com credenciais inventadas.

## Correção de layout pessoal — 21/10/2026

Botões do tema usam largura mínima finita (`Size(64, 50)`). `Size.fromHeight(50)` define largura infinita e quebrava os botões dentro de linhas, deixando o módulo pessoal sem layout. O cabeçalho se ajusta a telas estreitas, o status compacto de conexão tem texto reduzido e os títulos do Resumo podem quebrar linha. O menu de conta corporativa oferece saída explícita para troca de conta, preservando o espaço pessoal configurado.

Testes `personal_layout_test.dart` verificam as cinco abas com o tema real, em 360 e 640 pixels, com e sem cômodo/móvel/pertence/tarefa. Não houve alteração de dados ou API nesta correção.

## Recuperação e convites por e-mail — 07/11/2026

O login oferece **Esqueceu a senha?**, com tela nativa para código salvo ou recebido por e-mail. A solicitação de e-mail aparece somente quando a API informa que o SMTP está configurado. Códigos de e-mail valem por 15 minutos, são de uso único e o reset encerra as sessões antigas. Contas Google/Microsoft usam a recuperação do próprio provedor.

Em **Equipe e convites**, criar convite gera apenas o código. O diálogo de um convite com destinatário permite **Enviar por e-mail**, uma chamada on-line separada e autenticada. Recusa do provedor mantém o código para compartilhar. O sucesso indica aceitação SMTP, sem comprovar chegada à caixa de entrada.

Somente a API guarda `MAIL_*`; não coloque credenciais SMTP em defines, assets, Flutter ou Git. O envio permanece desativado até o responsável configurar provedor/remetente. Os testes cobrem a tela em largura de celular e HTTP controlado; a homologação em aparelho e e-mail real continua pendente. Consulte `docs/operations/TRANSACTIONAL_EMAIL.md` na raiz do repositório.

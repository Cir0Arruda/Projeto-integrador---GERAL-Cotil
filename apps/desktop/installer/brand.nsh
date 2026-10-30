!ifndef ASTHA_INSTALLER_BRAND
!define ASTHA_INSTALLER_BRAND

SetFont "Segoe UI" 10

!macro customHeader
  BrandingText "ASTHA RAVEN | Desktop"
!macroend

!define MUI_BGCOLOR "FFFFFF"
!define MUI_TEXTCOLOR "111318"
!define MUI_INSTFILESPAGE_COLORS "111318 FFFFFF"
!define MUI_HEADER_TRANSPARENT_TEXT
!define MUI_WELCOMEPAGE_TITLE "Bem-vindo ao ASTHA RAVEN"
!define MUI_WELCOMEPAGE_TEXT "Seu espaço de trabalho, em uma visão mais clara.$\r$\n$\r$\nInstale o cliente Desktop para acessar seus materiais, ambientes e registros no ASTHA.$\r$\n$\r$\nA conexão com o servidor utiliza HTTPS.$\r$\n$\r$\nSelecione Próximo para continuar."
!define MUI_FINISHPAGE_TITLE "Tudo pronto para começar"
!define MUI_FINISHPAGE_TEXT "O ASTHA RAVEN foi instalado.$\r$\n$\r$\nAbra o aplicativo, entre na sua conta e continue no seu espaço de trabalho."
!define MUI_FINISHPAGE_RUN_TEXT "Abrir ASTHA RAVEN"
!define MUI_UNWELCOMEPAGE_TITLE "Desinstalar ASTHA RAVEN"
!define MUI_UNWELCOMEPAGE_TEXT "Este assistente remove o cliente Desktop deste computador.$\r$\n$\r$\nSua conta e os registros no servidor não são excluídos por esta desinstalação.$\r$\n$\r$\nFeche o aplicativo antes de continuar."
!define MUI_UNFINISHPAGE_TITLE "Desinstalação concluída"
!define MUI_UNFINISHPAGE_TEXT "O cliente Desktop foi removido deste computador.$\r$\n$\r$\nSua conta e os dados do servidor continuam disponíveis."

!macro AsthaGui FUNCTION_NAME
Function ${FUNCTION_NAME}
  CreateFont $R0 "Segoe UI" 10 400
  GetDlgItem $R1 $HWNDPARENT 1
  GetDlgItem $R2 $HWNDPARENT 3
  GetDlgItem $R3 $HWNDPARENT 2
  SendMessage $R1 0x0030 $R0 1
  SendMessage $R2 0x0030 $R0 1
  SendMessage $R3 0x0030 $R0 1
  SetCtlColors $HWNDPARENT "111318" "FFFFFF"
  GetDlgItem $R4 $HWNDPARENT 1034
  SetCtlColors $R4 "65738A" "FFFFFF"
  SetCtlColors $R1 "FFFFFF" "111318"
  SetCtlColors $R2 "111318" "FFFFFF"
  SetCtlColors $R3 "65738A" "FFFFFF"
FunctionEnd
!macroend

!macro AsthaPageTheme FUNCTION_NAME
Function ${FUNCTION_NAME}
  Push $0
  Push $1
  FindWindow $0 "#32770" "" $HWNDPARENT
  SetCtlColors $0 "111318" "FFFFFF"
  System::Call 'user32::GetWindow(p $0, i 5) p .r1'
  loop:
    StrCmp $1 0 done
    SetCtlColors $1 "111318" "FFFFFF"
    System::Call 'user32::GetWindow(p $1, i 2) p .r1'
    Goto loop
  done:
  Pop $1
  Pop $0
FunctionEnd
!macroend
!ifdef BUILD_UNINSTALLER
  !define MUI_CUSTOMFUNCTION_UNGUIINIT un.AsthaGuiInit
  !insertmacro AsthaGui un.AsthaGuiInit
  !insertmacro AsthaPageTheme un.AsthaModeShow
!else
  !define MUI_CUSTOMFUNCTION_GUIINIT AsthaGuiInit
  !insertmacro AsthaGui AsthaGuiInit
  !insertmacro AsthaPageTheme AsthaModeShow
!endif

!macro customWelcomePage
  !insertmacro MUI_PAGE_WELCOME
  !define MUI_PAGE_CUSTOMFUNCTION_SHOW AsthaModeShow
!macroend

!macro customUnWelcomePage
  !insertmacro MUI_UNPAGE_WELCOME
  !define MUI_PAGE_CUSTOMFUNCTION_SHOW un.AsthaModeShow
!macroend
!endif

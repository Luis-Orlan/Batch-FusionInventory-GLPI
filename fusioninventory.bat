@echo off
setlocal enableextensions enabledelayedexpansion

REM BATCH PARA INSTALAÇÃO DO FusionInventory
REM FEITO POR ORLAN ROCHA
REM GITHUB = https://github.com/Luis-Orlan

REM ========================
REM CONFIGURAÇÕES AJUSTÁVEIS
REM ========================
set "versao=2.6"
set "ip_server=127.0.0.1"
set "caminhoGLPI=glpi/plugins/fusioninventory"
set "tarefas=Full"
set "porta_status=62354"

REM Controle das ações opcionais
set "desabilitar_firewall=sim"
set "habilitar_rdp=sim"
set "tempo_espera_instalacao=30"

set "setup_options=/S /acceptlicense /runnow /installtasks=%tarefas% /httpd-trust='127.0.0.1/32,%ip_server%' /scan-homedirs /scan-profiles /server='http://%ip_server%/%caminhoGLPI%/'"

call :log "Iniciando"
call :log "Hostname %computername%"

call :require_admin || goto :sair

if /I "%desabilitar_firewall%"=="sim" call :configure_firewall
if /I "%habilitar_rdp%"=="sim" call :configure_rdp

call :verificar_servico

if /I "!instalar!"=="nao" (
    call :log "O FusionInventory !arq_system! já está instalado e em execução"
    call :verificar_status
    goto :sair
)

if /I "!instalar!"=="condicional" (
    call :log "O serviço do FusionInventory foi encontrado, mas está parado. Tentando iniciar"
    call :iniciar_servico
    if errorlevel 1 (
        call :log "Não foi possível iniciar o serviço existente. Seguindo com a reinstalação"
    ) else (
        call :log "Serviço iniciado com sucesso sem reinstalar"
        call :verificar_status
        goto :sair
    )
)

call :log "Será necessário instalar o FusionInventory !arq_system!"
call :remover_instalacao_antiga
call :baixar_agente || goto :sair
call :instalar_agente
call :configurar_servico
call :verificar_status

call :log "FIM"
goto :fim

:sair
call :log "Execução encerrada"

:fim
endlocal
exit /b 0

REM ========================
REM        FUNÇÕES
REM ========================

:log
for /f "tokens=1 delims=." %%I in ("%time%") do set "horario=%%I"
echo [!horario!] FusionInventory-Agent: %~1
exit /b 0

:require_admin
net session >nul 2>&1
if errorlevel 1 (
    call :log "É necessário executar este script como Administrador"
    exit /b 1
)
exit /b 0

:configure_firewall
call :log "Ajustando Windows Firewall"
netsh advfirewall set allprofiles state off>nul 2>&1
netsh advfirewall set domainprofile state off>nul 2>&1
netsh advfirewall set privateprofile state off>nul 2>&1
netsh advfirewall set publicprofile state off>nul 2>&1
exit /b 0

:configure_rdp
call :log "Ajustando serviço de Área de Trabalho Remota"
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes>nul 2>&1
sc config RemoteRegistry start=auto>nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f>nul 2>&1
net stop remoteregistry>nul 2>&1
net start remoteregistry>nul 2>&1
exit /b 0

:verificar_servico
set "servico=FusionInventory-Agent"
set "instalar=sim"
set "estado_servico="
for /f "tokens=4" %%I in ('sc query "!servico!" ^| findstr /I "STATE"') do set "estado_servico=%%I"
if defined estado_servico (
    if /I "!estado_servico!"=="RUNNING" (
        set "instalar=nao"
    ) else (
        set "instalar=condicional"
    )
)
call :detectar_arquitetura
exit /b 0

:detectar_arquitetura
set "arq_system=x86"
if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "arq_system=x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "arq_system=x64"
exit /b 0

:remover_instalacao_antiga
for %%A in ("%ProgramFiles%\FusionInventory-Agent","%ProgramFiles(x86)%\FusionInventory-Agent") do (
    if exist %%~A (
        pushd %%~A
        call Uninstall.exe /S>nul 2>&1
        popd
    )
)
exit /b 0

:baixar_agente
set "destino=%ProgramData%\fusioninventory-agent_windows-!arq_system!_%versao%.exe"
set "downloadAgente=http://%ip_server%/%caminhoGLPI%/agent/fusioninventory-agent_windows-!arq_system!_%versao%.exe"

if exist "!destino!" del /f /q "!destino!">nul 2>&1

call :log "Efetuando download do agente em !destino!"

bitsadmin /RESET /ALLUSERS>nul 2>&1
bitsadmin /transfer FusionInventory /download /priority normal "!downloadAgente!" "!destino!">nul 2>&1

if not exist "!destino!" (
    call :log "BITSADMIN indisponível ou download falhou, tentando via PowerShell"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%downloadAgente%' -OutFile '%destino%' -UseBasicParsing } catch { exit 1 }" >nul 2>&1
)

if not exist "!destino!" (
    call :log "PowerShell indisponível ou download falhou, tentando via curl"
    curl -f -L "!downloadAgente!" -o "!destino!" >nul 2>&1
)

if not exist "!destino!" (
    call :log "curl indisponível ou download falhou, tentando via certutil"
    certutil -urlcache -split -f "!downloadAgente!" "!destino!" >nul 2>&1
)

if not exist "!destino!" (
    call :log "Falha no download do agente"
    exit /b 1
)

exit /b 0

:instalar_agente
call :log "Iniciando instalação"
pushd "%ProgramData%"
call fusioninventory-agent_windows-!arq_system!_%versao%.exe %setup_options%>nul 2>&1
popd

call :log "Aguardando !tempo_espera_instalacao! segundos para conclusão da instalação"
timeout /t !tempo_espera_instalacao! >nul
exit /b 0

:configurar_servico
set "servico=FusionInventory-Agent"
sc config "!servico!" start=delayed-auto>nul 2>&1
sc failure "!servico!" actions=restart/60000/restart/60000/restart/60000 reset=3600000>nul 2>&1
net start "!servico!">nul 2>&1
exit /b 0

:iniciar_servico
set "servico=FusionInventory-Agent"
net start "!servico!">nul 2>&1
if errorlevel 1 exit /b 1
exit /b 0

:verificar_status
curl -s http://localhost:%porta_status%/status | find "status:" >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { if ((Invoke-WebRequest -Uri 'http://localhost:%porta_status%/status' -UseBasicParsing).Content -match 'status:') { exit 0 } else { exit 2 } } catch { exit 1 }" >nul 2>&1
    if errorlevel 1 goto :verificar_status_falha
)
goto :verificar_status_sucesso

:verificar_status_falha
call :log "Não foi possível obter o status pela porta %porta_status%"
exit /b 1

:verificar_status_sucesso
call :log "Status do agente obtido com sucesso"
exit /b 0

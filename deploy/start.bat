@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1
title Zhoudai - Starting...

:: ============================================================
::  舟岱自动化小助手 - Windows 一键启动器 v2.1
::  有Docker用Docker，没Docker用原生Node.js
::  兼容 Windows 10 / Windows 11 (x64)
:: ============================================================

:: 获取项目根目录 (deploy文件夹的上级)
set "DEPLOY_DIR=%~dp0"
if "%DEPLOY_DIR:~-1%"=="\" set "DEPLOY_DIR=%DEPLOY_DIR:~0,-1%"
for %%i in ("%DEPLOY_DIR%\..") do set "INSTALL_DIR=%%~fi"

echo.
echo  ====================================================
echo      舟岱自动化小助手 - Beta 1.0
echo      Zhoudai Automation Assistant
echo      舟岱收费中心出品
echo  ====================================================
echo.

:: 创建日志目录
if not exist "%INSTALL_DIR%\logs" mkdir "%INSTALL_DIR%\logs" 2>nul
echo [%date% %time%] 启动器启动 > "%INSTALL_DIR%\logs\startup.log"
echo [%date% %time%] 目录=%INSTALL_DIR% >> "%INSTALL_DIR%\logs\startup.log"

echo  [1/5] 正在检测运行环境...

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [提示] 正在请求管理员权限...
    powershell -Command "Start-Process -FilePath cmd.exe -ArgumentList '/c cd /d "%INSTALL_DIR%" && "%~f0"' -Verb RunAs"
    exit /b
)

:: 检测Docker
set "USE_DOCKER=0"
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    docker info >nul 2>&1
    if %errorlevel% equ 0 set "USE_DOCKER=1"
)

if "!USE_DOCKER!"=="1" (
    echo  [OK] 检测到Docker，使用容器模式
    call :START_DOCKER
) else (
    echo  [i] 未检测到Docker，使用原生Node.js模式
    call :START_NATIVE
)
goto :EOF


:: ================================================================
:START_DOCKER
echo.
echo  -- Docker容器模式 --
call :CHECK_ENV_FILE
if %errorlevel% neq 0 goto :SETUP_FAILED

echo  [2/5] 检测Docker镜像...
set "IMAGE_FOUND=0"
docker image inspect zhoudai-assistant:latest >nul 2>&1
if %errorlevel% equ 0 set "IMAGE_FOUND=1"

if "!IMAGE_FOUND!"=="0" (
    if exist "%INSTALL_DIR%\offline\zhoudai-image.tar.gz" (
        echo  [导入] 正在载入离线镜像包 (1-3分钟)...
        docker load -i "%INSTALL_DIR%\offline\zhoudai-image.tar.gz"
        if !errorlevel! neq 0 goto :SETUP_FAILED
    ) else (
        echo  [构建] 本地构建镜像 (首次约10-20分钟)...
        cd /d "%INSTALL_DIR%"
        docker build -t zhoudai-assistant:latest -f Dockerfile.china .
        if !errorlevel! neq 0 goto :SETUP_FAILED
    )
)

echo  [3/5] 启动容器...
docker stop zhoudai-assistant >nul 2>&1
docker rm zhoudai-assistant >nul 2>&1
if not exist "%INSTALL_DIR%\data\zhoudai" mkdir "%INSTALL_DIR%\data\zhoudai"
cd /d "%INSTALL_DIR%"
docker-compose -f deploy\docker-compose.china.yml up -d
if %errorlevel% neq 0 goto :SETUP_FAILED

echo  [4/5] 等待服务就绪...
call :WAIT_FOR_SERVICE
goto :OPEN_BROWSER


:: ================================================================
:START_NATIVE
echo.
echo  -- 原生Node.js模式 --

if not exist "%INSTALL_DIR%\node_modules" (
    echo  [2/5] 首次运行，初始化环境 (约15-30分钟)...
    call :NATIVE_SETUP
    if !errorlevel! neq 0 goto :SETUP_FAILED
) else (
    echo  [2/5] 检测到已安装依赖，跳过安装
)

if not exist "%INSTALL_DIR%\dist\index.js" (
    echo  [3/5] 构建项目 (约2-5分钟)...
    call :NATIVE_BUILD
    if !errorlevel! neq 0 goto :SETUP_FAILED
) else (
    echo  [3/5] 已有构建产物，跳过构建
)

call :CHECK_ENV_FILE
if %errorlevel% neq 0 goto :SETUP_FAILED

echo  [4/5] 启动网关服务...
call :NATIVE_START
if %errorlevel% neq 0 goto :SETUP_FAILED

echo  [5/5] 等待服务就绪...
call :WAIT_FOR_SERVICE
goto :OPEN_BROWSER


:: ================================================================
:NATIVE_SETUP
echo.
echo  -- 环境检查与初始化 --

node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :INSTALL_NODE
    if !errorlevel! neq 0 exit /b 1
) else (
    for /f "tokens=2 delims=v." %%a in ('node --version 2^>nul') do set "NODE_VER=%%a"
    if !NODE_VER! LSS 22 (
        echo  [!] Node.js版本过低，需要v22+，重新安装...
        call :INSTALL_NODE
        if !errorlevel! neq 0 exit /b 1
    ) else (
        echo  [OK] Node.js版本满足要求
    )
)

pnpm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [安装] 正在安装pnpm包管理器...
    call :SET_NPM_MIRROR
    npm install -g pnpm@10.23.0 --registry https://registry.npmmirror.com
    if !errorlevel! neq 0 ( echo  [失败] pnpm安装失败 & exit /b 1 )
    echo  [OK] pnpm安装成功
)

call :SET_NPM_MIRROR

if exist "%INSTALL_DIR%\offline\node_modules.tar.gz" (
    echo  [解压] 从离线包解压依赖 (1-2分钟)...
    cd /d "%INSTALL_DIR%"
    tar -xzf offline\node_modules.tar.gz
    if !errorlevel! equ 0 ( echo  [OK] 离线解压完成 & exit /b 0 )
    echo  [!] 解压失败，改为在线安装...
)

echo  [下载] 安装项目依赖 (首次约5-15分钟，请耐心等待)...
echo  [i] 使用国内镜像源 npmmirror.com 加速...
cd /d "%INSTALL_DIR%"
pnpm install --frozen-lockfile 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ====================================================
    echo   [失败] 依赖安装失败！请检查：
    echo    1. 网络是否正常
    echo    2. 磁盘空间是否足够 (需至少5GB)
    echo    3. 运行 deploy\setup-buildtools.bat 安装编译工具
    echo  ====================================================
    exit /b 1
)
echo  [OK] 依赖安装完成
exit /b 0


:: ================================================================
:NATIVE_BUILD
cd /d "%INSTALL_DIR%"
call pnpm run build 2>&1
if %errorlevel% neq 0 ( echo  [失败] 构建失败 & exit /b 1 )
echo  [OK] 构建完成
exit /b 0


:: ================================================================
:NATIVE_START
cd /d "%INSTALL_DIR%"
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 ( echo  [OK] 服务已在运行 & exit /b 0 )

if not exist "%INSTALL_DIR%\logs" mkdir "%INSTALL_DIR%\logs"

if exist "%INSTALL_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%INSTALL_DIR%\.env") do (
        set "_L=%%a"
        if "!_L:~0,1!" neq "#" if "!_L!" neq "" set "%%a=%%b"
    )
)

echo  [启动] 后台启动网关服务...
start /b "" node "%INSTALL_DIR%\openclaw.mjs" gateway --port 18788 > "%INSTALL_DIR%\logs\gateway.log" 2>&1
exit /b 0


:: ================================================================
:INSTALL_NODE
echo  [安装] 正在安装Node.js v22...
if exist "%INSTALL_DIR%\offline\node-v22-x64.msi" (
    echo  [i] 使用离线安装包...
    msiexec /i "%INSTALL_DIR%\offline\node-v22-x64.msi" /quiet /norestart ADDLOCAL=ALL
    call :REFRESH_PATH
    echo  [OK] Node.js安装完成（离线包）
    exit /b 0
)
set "NODE_URL=https://npmmirror.com/mirrors/node/v22.12.0/node-v22.12.0-x64.msi"
set "NODE_SAVE=%TEMP%\node-v22-installer.msi"
echo  [下载] 从国内镜像下载Node.js (约80MB)...
powershell -Command "& { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_SAVE%' -UseBasicParsing }"
if %errorlevel% neq 0 (
    echo  [失败] 下载失败
    echo  [i] 手动下载: https://npmmirror.com/mirrors/node/v22.12.0/
    exit /b 1
)
msiexec /i "%NODE_SAVE%" /quiet /norestart ADDLOCAL=ALL
call :REFRESH_PATH
echo  [OK] Node.js v22安装完成
exit /b 0


:: ================================================================
:CHECK_ENV_FILE
if exist "%INSTALL_DIR%\.env" (
    findstr /c:"GATEWAY_TOKEN=" "%INSTALL_DIR%\.env" >nul 2>&1
    if !errorlevel! equ 0 ( echo  [OK] 配置文件已就绪 & exit /b 0 )
)
echo.
echo  ====================================================
echo      首次配置向导
echo  ====================================================
echo.
echo  请选择您要使用的AI服务：
echo.
echo  [1] DeepSeek      国内直连，性价比最高  [推荐]
echo  [2] 通义千问      阿里云，国内直连
echo  [3] Kimi          月之暗面，国内直连
echo  [4] OpenAI        需要代理
echo  [5] Anthropic     需要代理
echo  [6] 暂不配置      稍后手动编辑.env文件
echo.
set /p AI_CHOICE="  请输入数字 (1-6): "
for /f %%i in ('powershell -Command "[guid]::NewGuid().ToString().Replace('-','').Substring(0,32)"') do set "GW_TOKEN=%%i"
(
echo # 舟岱自动化小助手 配置文件
echo ZHOUDAI_GATEWAY_TOKEN=%GW_TOKEN%
echo OPENCLAW_GATEWAY_TOKEN=%GW_TOKEN%
echo ZHOUDAI_STATE_DIR=./data/zhoudai
echo OPENCLAW_STATE_DIR=./data/zhoudai
) > "%INSTALL_DIR%\.env"
if "!AI_CHOICE!"=="1" (
    set /p DS_KEY="  DeepSeek API Key (sk-...): "
    echo OPENAI_API_KEY=!DS_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://api.deepseek.com >> "%INSTALL_DIR%\.env"
)
if "!AI_CHOICE!"=="2" (
    set /p QW_KEY="  通义千问 API Key: "
    echo OPENAI_API_KEY=!QW_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1 >> "%INSTALL_DIR%\.env"
)
if "!AI_CHOICE!"=="3" (
    set /p KM_KEY="  Kimi API Key (sk-...): "
    echo OPENAI_API_KEY=!KM_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://api.moonshot.cn/v1 >> "%INSTALL_DIR%\.env"
)
if "!AI_CHOICE!"=="4" (
    set /p OA_KEY="  OpenAI API Key (sk-...): "
    echo OPENAI_API_KEY=!OA_KEY! >> "%INSTALL_DIR%\.env"
)
if "!AI_CHOICE!"=="5" (
    set /p AN_KEY="  Anthropic API Key: "
    echo ANTHROPIC_API_KEY=!AN_KEY! >> "%INSTALL_DIR%\.env"
)
echo.
echo  [OK] 配置已保存！
echo.
echo  *** 重要：请记录您的网关令牌 ***
echo  %GW_TOKEN%
echo  （首次访问Web控制台需要输入此令牌）
echo.
pause
exit /b 0


:: ================================================================
:SET_NPM_MIRROR
npm config set registry https://registry.npmmirror.com >nul 2>&1
npm config set disturl https://npmmirror.com/mirrors/node >nul 2>&1
npm config set sharp_dist_base_url https://npmmirror.com/mirrors/sharp-libvips/ >nul 2>&1
pnpm config set registry https://registry.npmmirror.com >nul 2>&1
exit /b 0


:: ================================================================
:WAIT_FOR_SERVICE
set "RETRY=0"
:_WAIT_LOOP
set /a RETRY+=1
if %RETRY% GTR 30 ( echo  [!] 服务启动超时，请查看日志 & goto :_WAIT_DONE )
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 goto :_WAIT_DONE
timeout /t 2 /nobreak >nul
<nul set /p =.
goto :_WAIT_LOOP
:_WAIT_DONE
echo.
echo  [OK] 服务已就绪！
exit /b 0


:: ================================================================
:REFRESH_PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%b"
set "PATH=!SYS_PATH!;!USR_PATH!;%PATH%"
exit /b 0


:: ================================================================
:OPEN_BROWSER
echo.
echo  ====================================================
echo   舟岱自动化小助手已启动！
echo   访问地址: http://localhost:18788
echo   （查看.env文件获取网关令牌）
echo  ====================================================
echo.
timeout /t 2 /nobreak >nul
start "" "http://localhost:18788"
echo  按任意键关闭此窗口（服务继续后台运行）
pause >nul
exit /b 0


:: ================================================================
:SETUP_FAILED
echo.
echo  ====================================================
echo   启动失败，请检查：
echo   1. 是否以管理员身份运行
echo   2. 网络是否正常
echo   3. 查看 logs\startup.log 和 logs\gateway.log
echo   4. 参阅 deploy\员工使用指南.md
echo  ====================================================
echo.
pause
exit /b 1

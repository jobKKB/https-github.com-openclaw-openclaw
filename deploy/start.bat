@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1

:: =========================================================
:: 舟岱自动化小助手 - 启动器 v3.0
:: 如有问题，日志保存在: 项目目录\logs\startup.log
:: =========================================================

:: --- 第一步：确定项目根目录 ---
:: start.bat 放在 deploy\ 下，项目根是上一级
set "DEPLOY_DIR=%~dp0"
if "%DEPLOY_DIR:~-1%"=="\" set "DEPLOY_DIR=%DEPLOY_DIR:~0,-1%"
for %%i in ("%DEPLOY_DIR%\..") do set "ROOT=%%%~fi"

:: 如果路径解析失败，用备用方法
if not defined ROOT set "ROOT=%DEPLOY_DIR%\.."
if not exist "%ROOT%\package.json" (
    :: 尝试当前目录的上级
    for %%i in ("%CD%\..") do set "ROOT=%%~fi"
)

:: --- 第二步：建立日志目录和文件 ---
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" 2>nul
set "LOG=%ROOT%\logs\startup.log"
echo [%date% %time%] ===== 启动器 v3.0 ===== > "%LOG%"
echo [%date% %time%] DEPLOY_DIR=%DEPLOY_DIR% >> "%LOG%"
echo [%date% %time%] ROOT=%ROOT% >> "%LOG%"

:: --- 第三步：管理员权限检查 ---
:: 方法：尝试写入系统目录，失败说明没有管理员权限
net session >nul 2>&1
set "IS_ADMIN=%errorlevel%"
echo [%date% %time%] IS_ADMIN_CHECK=%IS_ADMIN% >> "%LOG%"

if "%IS_ADMIN%" neq "0" (
    echo [%date% %time%] 无管理员权限，尝试提权 >> "%LOG%"
    :: 使用 PowerShell 提权重新运行自身
    :: 注意：这里用 -Wait 确保等待子进程完成
    powershell -NoProfile -Command ^
        "Start-Process -FilePath '%COMSPEC%' -ArgumentList '/c chcp 936 && cd /d "%ROOT%" && call "%~f0"' -Verb RunAs -Wait"
    exit /b 0
)

echo [%date% %time%] 管理员权限确认 >> "%LOG%"
echo  [OK] 管理员权限已确认

:: --- 第四步：验证项目目录 ---
if not exist "%ROOT%\package.json" (
    echo [%date% %time%] 错误：找不到package.json，ROOT=%ROOT% >> "%LOG%"
    echo.
    echo  [错误] 找不到项目文件！
    echo  当前检测路径: %ROOT%
    echo.
    echo  请确认：deploy\start.bat 是否在项目的 deploy 子目录中？
    echo  正确结构示例：
    echo    D:\zhoudai\                ^<-- 项目根目录
    echo      deploy\
    echo        start.bat             ^<-- 本文件位置
    echo      package.json           ^<-- 应该在这里
    echo.
    pause
    exit /b 1
)

echo [%date% %time%] 项目目录确认: %ROOT% >> "%LOG%"
echo  [OK] 项目目录: %ROOT%

:: --- 第五步：检测 Docker ---
set "USE_DOCKER=0"
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        set "USE_DOCKER=1"
        echo [%date% %time%] 检测到Docker >> "%LOG%"
    )
)

if "%USE_DOCKER%"=="1" (
    echo  [OK] 检测到 Docker，使用容器模式
    call :MODE_DOCKER
) else (
    echo  [i]  未检测到 Docker，使用原生 Node.js 模式
    call :MODE_NATIVE
)
goto :END


:: =========================================================
:MODE_DOCKER
:: =========================================================
echo [%date% %time%] 进入Docker模式 >> "%LOG%"
echo.
echo  -- Docker 容器模式 --

call :SETUP_ENV
if %errorlevel% neq 0 goto :FAIL

echo  [2/5] 检查镜像...
docker image inspect zhoudai-assistant:latest >nul 2>&1
if %errorlevel% neq 0 (
    if exist "%ROOT%\offline\zhoudai-image.tar.gz" (
        echo  [导入] 载入离线镜像，请稍候...
        docker load -i "%ROOT%\offline\zhoudai-image.tar.gz" >> "%LOG%" 2>&1
        if !errorlevel! neq 0 goto :FAIL
    ) else (
        echo  [构建] 本地构建镜像，首次约需10-20分钟...
        cd /d "%ROOT%"
        docker build -t zhoudai-assistant:latest -f Dockerfile.china . >> "%LOG%" 2>&1
        if !errorlevel! neq 0 goto :FAIL
    )
)

echo  [3/5] 启动容器...
docker stop zhoudai-assistant >nul 2>&1
docker rm zhoudai-assistant >nul 2>&1
if not exist "%ROOT%\data\zhoudai" mkdir "%ROOT%\data\zhoudai"
cd /d "%ROOT%"
docker-compose -f deploy\docker-compose.china.yml up -d >> "%LOG%" 2>&1
if %errorlevel% neq 0 goto :FAIL

echo  [4/5] 等待服务...
call :WAIT_HTTP
echo  [5/5] 完成！
goto :OPEN_BROWSER


:: =========================================================
:MODE_NATIVE
:: =========================================================
echo [%date% %time%] 进入原生模式 >> "%LOG%"
echo.
echo  -- 原生 Node.js 模式 --

:: 检查是否已安装依赖
if not exist "%ROOT%\node_modules" (
    echo  [2/5] 首次运行，初始化环境（约15-30分钟）...
    call :NATIVE_INSTALL
    if !errorlevel! neq 0 goto :FAIL
) else (
    echo  [2/5] 依赖已就绪，跳过安装
)

:: 检查是否已构建
if not exist "%ROOT%\dist\index.js" (
    echo  [3/5] 构建项目（约2-5分钟）...
    call :NATIVE_BUILD
    if !errorlevel! neq 0 goto :FAIL
) else (
    echo  [3/5] 构建产物已就绪，跳过构建
)

call :SETUP_ENV
if %errorlevel% neq 0 goto :FAIL

echo  [4/5] 启动服务...
call :NATIVE_START
if %errorlevel% neq 0 goto :FAIL

echo  [5/5] 等待服务...
call :WAIT_HTTP
goto :OPEN_BROWSER


:: =========================================================
:NATIVE_INSTALL
:: =========================================================
:: 检查 Node.js
node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :INSTALL_NODEJS
    if !errorlevel! neq 0 exit /b 1
)

:: 检查版本
for /f "tokens=2 delims=v." %%v in ('node --version 2^>nul') do set "NV=%%v"
if defined NV if !NV! LSS 22 (
    echo  [!] Node.js 版本过低（检测到v!NV!，需要v22+），重新安装...
    call :INSTALL_NODEJS
    if !errorlevel! neq 0 exit /b 1
)

:: 检查 pnpm
pnpm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [安装] 安装 pnpm...
    call :SET_MIRROR
    npm install -g pnpm@10.23.0 --registry https://registry.npmmirror.com >> "%LOG%" 2>&1
    if !errorlevel! neq 0 ( echo  [失败] pnpm 安装失败，见日志 & exit /b 1 )
)

call :SET_MIRROR

:: 离线包优先
if exist "%ROOT%\offline\node_modules.tar.gz" (
    echo  [解压] 从离线包解压依赖...
    cd /d "%ROOT%"
    tar -xzf offline\node_modules.tar.gz >> "%LOG%" 2>&1
    if !errorlevel! equ 0 ( echo  [OK] 离线解压完成 & exit /b 0 )
)

:: 在线安装
echo  [下载] 在线安装依赖（5-15分钟，请耐心）...
echo  [i]  使用国内镜像源加速...
cd /d "%ROOT%"
pnpm install --frozen-lockfile >> "%LOG%" 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  [失败] 依赖安装失败！请查看日志: %LOG%
    echo  常见原因：1.网络问题  2.磁盘不足(需5GB+)  3.缺少编译工具
    echo  解决：运行 deploy\setup-buildtools.bat 后重试
    exit /b 1
)
echo  [OK] 依赖安装完成
exit /b 0


:: =========================================================
:NATIVE_BUILD
:: =========================================================
cd /d "%ROOT%"
call pnpm run build >> "%LOG%" 2>&1
if %errorlevel% neq 0 (
    echo  [失败] 构建失败，查看日志: %LOG%
    exit /b 1
)
echo  [OK] 构建完成
exit /b 0


:: =========================================================
:NATIVE_START
:: =========================================================
cd /d "%ROOT%"
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 ( echo  [OK] 服务已在运行 & exit /b 0 )

:: 加载 .env
if exist "%ROOT%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%ROOT%\.env") do (
        set "_k=%%a"
        if "!_k:~0,1!" neq "#" if "!_k!" neq "" set "%%a=%%b"
    )
)

echo [%date% %time%] 启动gateway进程 >> "%LOG%"
start "" /b cmd /c "node "%ROOT%\openclaw.mjs" gateway --port 18788 >> "%ROOT%\logs\gateway.log" 2>&1"
exit /b 0


:: =========================================================
:INSTALL_NODEJS
:: =========================================================
echo  [安装] 安装 Node.js v22...
if exist "%ROOT%\offline\node-v22-x64.msi" (
    msiexec /i "%ROOT%\offline\node-v22-x64.msi" /quiet /norestart ADDLOCAL=ALL
    call :RELOAD_PATH & exit /b 0
)
set "N_URL=https://npmmirror.com/mirrors/node/v22.12.0/node-v22.12.0-x64.msi"
set "N_TMP=%TEMP%\node22.msi"
echo  [下载] 从国内镜像下载 Node.js（约80MB）...
powershell -NoProfile -Command "$p='SilentlyContinue';$ProgressPreference=$p;Invoke-WebRequest '%N_URL%' -OutFile '%N_TMP%' -UseBasicParsing"
if %errorlevel% neq 0 ( echo  [失败] 下载失败，请检查网络 & exit /b 1 )
msiexec /i "%N_TMP%" /quiet /norestart ADDLOCAL=ALL
if %errorlevel% neq 0 ( echo  [失败] 安装失败 & exit /b 1 )
call :RELOAD_PATH
echo  [OK] Node.js v22 安装完成
exit /b 0


:: =========================================================
:SETUP_ENV
:: =========================================================
if exist "%ROOT%\.env" (
    findstr /c:"GATEWAY_TOKEN=" "%ROOT%\.env" >nul 2>&1
    if !errorlevel! equ 0 ( echo  [OK] .env 配置已就绪 & exit /b 0 )
)
echo.
echo  =============================================
echo    首次配置向导
echo  =============================================
echo.
echo  请选择 AI 服务：
echo  [1] DeepSeek   国内直连，最便宜  [推荐]
echo  [2] 通义千问   阿里云，国内直连
echo  [3] Kimi       月之暗面，国内直连
echo  [4] OpenAI     需要代理
echo  [5] Anthropic  需要代理
echo  [6] 暂不配置
echo.
set /p "AC=  输入数字(1-6): "
for /f %%g in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString('N').Substring(0,32)"') do set "GT=%%g"
(
echo # 舟岱配置文件
echo ZHOUDAI_GATEWAY_TOKEN=%GT%
echo OPENCLAW_GATEWAY_TOKEN=%GT%
echo ZHOUDAI_STATE_DIR=./data/zhoudai
echo OPENCLAW_STATE_DIR=./data/zhoudai
) > "%ROOT%\.env"
if "%AC%"=="1" ( set /p "K=  DeepSeek Key(sk-...): " & echo OPENAI_API_KEY=!K!>>"%ROOT%\.env" & echo OPENAI_BASE_URL=https://api.deepseek.com>>"%ROOT%\.env" )
if "%AC%"=="2" ( set /p "K=  通义千问 Key: " & echo OPENAI_API_KEY=!K!>>"%ROOT%\.env" & echo OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1>>"%ROOT%\.env" )
if "%AC%"=="3" ( set /p "K=  Kimi Key(sk-...): " & echo OPENAI_API_KEY=!K!>>"%ROOT%\.env" & echo OPENAI_BASE_URL=https://api.moonshot.cn/v1>>"%ROOT%\.env" )
if "%AC%"=="4" ( set /p "K=  OpenAI Key(sk-...): " & echo OPENAI_API_KEY=!K!>>"%ROOT%\.env" )
if "%AC%"=="5" ( set /p "K=  Anthropic Key: " & echo ANTHROPIC_API_KEY=!K!>>"%ROOT%\.env" )
echo.
echo  [OK] 配置已保存
echo  网关令牌: %GT%
echo  （首次访问 http://localhost:18788 需要输入此令牌）
echo.
pause
exit /b 0


:SET_MIRROR
npm config set registry https://registry.npmmirror.com >nul 2>&1
npm config set disturl https://npmmirror.com/mirrors/node >nul 2>&1
npm config set sharp_dist_base_url https://npmmirror.com/mirrors/sharp-libvips/ >nul 2>&1
pnpm config set registry https://registry.npmmirror.com >nul 2>&1
exit /b 0


:RELOAD_PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SP=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "UP=%%b"
set "PATH=!SP!;!UP!;%PATH%"
exit /b 0


:WAIT_HTTP
set "_r=0"
:_wl
set /a "_r+=1"
if %_r% gtr 30 ( echo. & echo  [!] 等待超时，请查看日志 & goto :_wd )
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 goto :_wd
timeout /t 2 /nobreak >nul
<nul set /p =.
goto :_wl
:_wd
echo.
echo  [OK] 服务就绪！
exit /b 0


:OPEN_BROWSER
echo.
echo  =============================================
echo   启动成功！
echo   访问: http://localhost:18788
echo   令牌: 查看 .env 文件中的 GATEWAY_TOKEN
echo  =============================================
echo.
timeout /t 2 /nobreak >nul
start "" http://localhost:18788
echo  按任意键关闭（服务继续后台运行）
pause >nul
goto :END


:FAIL
echo.
echo  =============================================
echo   启动失败！请查看日志：
echo   %LOG%
echo.
echo   常见解决方法：
echo   1. 以管理员身份运行
echo   2. 检查网络连接
echo   3. 运行 deploy\setup-buildtools.bat
echo  =============================================
echo.
pause
goto :END


:END
endlocal
exit /b 0

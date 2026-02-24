@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title 舟岱自动化小助手 - 启动中...

:: ============================================================
::  舟岱自动化小助手 - Windows 一键启动器 v2.0
::  支持：有Docker用Docker，没Docker用原生Node.js
::  兼容：Windows 10 / Windows 11 (x64)
::  作者：舟岱收费中心
:: ============================================================

echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║         舟 岱 自 动 化 小 助 手                           ║
echo  ║         Zhoudai Automation Assistant                      ║
echo  ║         版本: Beta 1.0   舟岱收费中心出品                 ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.

:: 获取脚本所在目录（即项目根目录）
set "INSTALL_DIR=%~dp0.."
pushd "%INSTALL_DIR%"
set "INSTALL_DIR=%CD%"
popd

:: ── 检查是否有管理员权限 ─────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [提示] 需要管理员权限，正在请求提升...
    powershell -Command "Start-Process -FilePath cmd.exe -ArgumentList '/c cd /d \"%INSTALL_DIR%\" && \"%~f0\"' -Verb RunAs -WorkingDirectory '%INSTALL_DIR%'"
    exit /b
)

echo  [1/5] 正在检测运行环境...
echo.

:: ── 优先检测 Docker ──────────────────────────────────────
set "USE_DOCKER=0"
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        set "USE_DOCKER=1"
    )
)

if "!USE_DOCKER!"=="1" (
    echo  [✓] 检测到 Docker，使用容器模式（推荐）
    goto :START_DOCKER
) else (
    echo  [i] 未检测到 Docker，使用原生 Node.js 模式
    echo  [i] （如需安装Docker，请参阅 deploy\员工安装说明.md）
    goto :START_NATIVE
)


:: ════════════════════════════════════════════════════════════
::  Docker 模式
:: ════════════════════════════════════════════════════════════
:START_DOCKER
echo.
echo  ─── Docker 容器模式 ─────────────────────────────────────────
call :CHECK_ENV_FILE
if %errorlevel% neq 0 goto :SETUP_FAILED

echo  [2/5] 检查 Docker 镜像...

set "IMAGE_FOUND=0"
docker image inspect zhoudai-assistant:latest >nul 2>&1
if %errorlevel% equ 0 set "IMAGE_FOUND=1"

if "!IMAGE_FOUND!"=="0" (
    :: 优先离线镜像包
    if exist "%INSTALL_DIR%\offline\zhoudai-image.tar.gz" (
        echo  [↓] 从离线包导入镜像（请稍候，约需1-3分钟）...
        docker load -i "%INSTALL_DIR%\offline\zhoudai-image.tar.gz"
        if !errorlevel! neq 0 ( echo  [✗] 镜像导入失败 & goto :SETUP_FAILED )
    ) else if exist "%INSTALL_DIR%\offline\zhoudai-image.tar" (
        echo  [↓] 从离线包导入镜像（请稍候，约需1-3分钟）...
        docker load -i "%INSTALL_DIR%\offline\zhoudai-image.tar"
        if !errorlevel! neq 0 ( echo  [✗] 镜像导入失败 & goto :SETUP_FAILED )
    ) else (
        echo  [↓] 从国内镜像源拉取（约需3-10分钟，请耐心等待）...
        docker pull registry.cn-hangzhou.aliyuncs.com/zhoudai/assistant:latest 2>nul
        if !errorlevel! equ 0 (
            docker tag registry.cn-hangzhou.aliyuncs.com/zhoudai/assistant:latest zhoudai-assistant:latest
        ) else (
            echo  [↓] 切换备用镜像源...
            docker pull ghcr.io/jobKKB/zhoudai-assistant:latest 2>nul
            if !errorlevel! equ 0 (
                docker tag ghcr.io/jobKKB/zhoudai-assistant:latest zhoudai-assistant:latest
            ) else (
                echo  [!] 无法拉取镜像，将切换到本地构建...
                goto :DOCKER_BUILD_LOCAL
            )
        )
    )
    echo  [✓] 镜像已就绪
)

goto :DOCKER_RUN

:DOCKER_BUILD_LOCAL
echo  [↓] 正在本地构建镜像（首次约需10-20分钟）...
docker build -t zhoudai-assistant:latest -f "%INSTALL_DIR%\Dockerfile.china" "%INSTALL_DIR%"
if %errorlevel% neq 0 (
    echo  [✗] 本地构建失败，请检查网络后重试
    goto :SETUP_FAILED
)
echo  [✓] 本地构建完成

:DOCKER_RUN
echo  [3/5] 启动容器服务...

:: 检查是否已在运行
docker ps --filter "name=zhoudai-assistant" --filter "status=running" --format "{{.Names}}" | findstr /i "zhoudai-assistant" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [✓] 服务已在运行中
    goto :OPEN_BROWSER
)

:: 停止旧容器
docker stop zhoudai-assistant >nul 2>&1
docker rm zhoudai-assistant >nul 2>&1

:: 创建数据目录
if not exist "%INSTALL_DIR%\data\zhoudai" mkdir "%INSTALL_DIR%\data\zhoudai"

:: 启动新容器
cd /d "%INSTALL_DIR%"
docker-compose -f deploy\docker-compose.china.yml up -d
if %errorlevel% neq 0 (
    echo  [✗] 容器启动失败
    goto :SETUP_FAILED
)

echo  [4/5] 等待服务就绪...
call :WAIT_FOR_SERVICE
echo  [5/5] 完成！

goto :OPEN_BROWSER


:: ════════════════════════════════════════════════════════════
::  原生 Node.js 模式（无 Docker）
:: ════════════════════════════════════════════════════════════
:START_NATIVE
echo.
echo  ─── 原生 Node.js 模式 ───────────────────────────────────────

:: 检查 node_modules 判断是否已安装
if not exist "%INSTALL_DIR%\node_modules" (
    echo  [2/5] 首次运行，开始环境初始化（约需5-15分钟）...
    call :NATIVE_SETUP
    if !errorlevel! neq 0 goto :SETUP_FAILED
) else (
    echo  [2/5] 检测到已安装的依赖包
)

:: 检查构建产物
if not exist "%INSTALL_DIR%\dist\index.js" (
    echo  [3/5] 首次构建项目（约需2-5分钟）...
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


:: ════════════════════════════════════════════════════════════
::  原生安装流程（首次）
:: ════════════════════════════════════════════════════════════
:NATIVE_SETUP
echo.
echo  ─── 环境检查与初始化 ────────────────────────────────────────

:: 检查并安装 Node.js
echo  [↓] 检查 Node.js...
node --version >nul 2>&1
if %errorlevel% neq 0 (
    call :INSTALL_NODE
    if !errorlevel! neq 0 exit /b 1
) else (
    :: 检查版本是否 >= 22
    for /f "tokens=1 delims=v." %%a in ('node --version 2^>nul') do set "_dummy=%%a"
    for /f "tokens=2 delims=v." %%a in ('node --version 2^>nul') do set "NODE_VER=%%a"
    if !NODE_VER! LSS 22 (
        echo  [!] 当前 Node.js 版本过低（需要 v22+），将重新安装...
        call :INSTALL_NODE
        if !errorlevel! neq 0 exit /b 1
    ) else (
        echo  [✓] Node.js 版本满足要求
    )
)

:: 检查 Visual C++ Build Tools（编译原生模块必需）
echo  [↓] 检查 Visual C++ 编译工具...
where cl.exe >nul 2>&1
if %errorlevel% neq 0 (
    reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0" >nul 2>&1
    if !errorlevel! neq 0 (
        reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\16.0" >nul 2>&1
        if !errorlevel! neq 0 (
            echo  [↓] 安装 Visual C++ Build Tools（约需3-5分钟）...
            call :INSTALL_BUILD_TOOLS
        )
    )
) else (
    echo  [✓] 编译工具已就绪
)

:: 检查并安装 pnpm
echo  [↓] 检查 pnpm...
pnpm --version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [↓] 安装 pnpm 包管理器...
    call :SET_NPM_MIRROR
    npm install -g pnpm@10.23.0 --registry https://registry.npmmirror.com
    if !errorlevel! neq 0 (
        echo  [✗] pnpm 安装失败，请检查网络
        exit /b 1
    )
    echo  [✓] pnpm 安装成功
) else (
    echo  [✓] pnpm 已就绪
)

:: 设置国内镜像（所有源）
call :SET_NPM_MIRROR

:: 检查是否有离线依赖包
if exist "%INSTALL_DIR%\offline\node_modules.tar.gz" (
    echo  [↓] 从离线包解压依赖（约需1-2分钟）...
    cd /d "%INSTALL_DIR%"
    tar -xzf offline\node_modules.tar.gz
    if !errorlevel! neq 0 (
        echo  [!] 解压失败，将改为在线安装...
        goto :ONLINE_INSTALL
    )
    echo  [✓] 离线依赖解压完成
    goto :INSTALL_DONE
)

:ONLINE_INSTALL
:: 在线安装依赖
echo  [↓] 安装项目依赖（首次约需5-15分钟，请耐心等待）...
echo  [i] 使用国内镜像源加速...
echo.
cd /d "%INSTALL_DIR%"
pnpm install --frozen-lockfile 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ┌─────────────────────────────────────────────┐
    echo  │  [✗] 依赖安装失败，请检查：                 │
    echo  │   1. 网络是否正常                           │
    echo  │   2. 磁盘剩余空间（需至少4GB）              │
    echo  │   3. 是否缺少编译工具（运行 setup-buildtools.bat） │
    echo  └─────────────────────────────────────────────┘
    exit /b 1
)

:INSTALL_DONE
echo  [✓] 依赖安装完成

exit /b 0


:: ════════════════════════════════════════════════════════════
::  构建项目
:: ════════════════════════════════════════════════════════════
:NATIVE_BUILD
echo.
echo  ─── 构建项目 ────────────────────────────────────────────────
cd /d "%INSTALL_DIR%"
call pnpm run build 2>&1
if %errorlevel% neq 0 (
    echo  [✗] 构建失败，请查看上方错误信息
    exit /b 1
)
echo  [✓] 构建完成
exit /b 0


:: ════════════════════════════════════════════════════════════
::  原生启动网关
:: ════════════════════════════════════════════════════════════
:NATIVE_START
cd /d "%INSTALL_DIR%"

:: 检查是否已在运行
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 (
    echo  [✓] 服务已在运行中
    exit /b 0
)

:: 创建日志目录
if not exist "%INSTALL_DIR%\logs" mkdir "%INSTALL_DIR%\logs"

:: 加载 .env 环境变量
if exist "%INSTALL_DIR%\.env" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%INSTALL_DIR%\.env") do (
        set "_L=%%a"
        if "!_L:~0,1!" neq "#" if "!_L!" neq "" (
            set "%%a=%%b"
        )
    )
)

:: 后台启动 gateway
echo  [↓] 正在后台启动网关服务...
start /b "zhoudai-gateway" node "%INSTALL_DIR%\openclaw.mjs" gateway --port 18788 > "%INSTALL_DIR%\logs\gateway.log" 2>&1

:: 如有 daemon 支持则注册为系统服务
node "%INSTALL_DIR%\openclaw.mjs" daemon install --silent >nul 2>&1

exit /b 0


:: ════════════════════════════════════════════════════════════
::  安装 Node.js 22（国内镜像）
:: ════════════════════════════════════════════════════════════
:INSTALL_NODE
echo  [↓] 安装 Node.js v22...

:: 检查离线包
if exist "%INSTALL_DIR%\offline\node-v22-x64.msi" (
    echo  [i] 使用离线安装包...
    msiexec /i "%INSTALL_DIR%\offline\node-v22-x64.msi" /quiet /norestart ADDLOCAL=ALL
    call :REFRESH_PATH
    echo  [✓] Node.js 安装完成（来自离线包）
    exit /b 0
)

:: 在线下载（国内npmmirror镜像）
set "NODE_VER_FULL=22.12.0"
set "NODE_URL=https://npmmirror.com/mirrors/node/v%NODE_VER_FULL%/node-v%NODE_VER_FULL%-x64.msi"
set "NODE_SAVE=%TEMP%\node-v22-installer.msi"

echo  [↓] 从国内镜像下载 Node.js（约80MB）...
powershell -Command "& { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%NODE_URL%' -OutFile '%NODE_SAVE%' -UseBasicParsing }" 2>nul
if %errorlevel% neq 0 (
    echo  [✗] Node.js 下载失败
    echo  [i] 请手动下载后放到 offline\node-v22-x64.msi 再运行
    echo      下载地址：https://npmmirror.com/mirrors/node/v22.12.0/
    exit /b 1
)

echo  [↓] 安装 Node.js（需要1-2分钟）...
msiexec /i "%NODE_SAVE%" /quiet /norestart ADDLOCAL=ALL
if %errorlevel% neq 0 (
    echo  [✗] Node.js 安装失败
    exit /b 1
)

call :REFRESH_PATH
echo  [✓] Node.js v22 安装完成
exit /b 0


:: ════════════════════════════════════════════════════════════
::  安装 Visual C++ Build Tools
:: ════════════════════════════════════════════════════════════
:INSTALL_BUILD_TOOLS
:: 尝试用 winget 安装（Win10 1709+ 自带）
winget --version >nul 2>&1
if %errorlevel% equ 0 (
    echo  [↓] 通过 winget 安装 Visual C++ 编译工具...
    winget install Microsoft.VisualStudio.2022.BuildTools --silent --accept-package-agreements --accept-source-agreements --override "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --wait"
    echo  [✓] 编译工具安装完成
    exit /b 0
)

:: 离线包
if exist "%INSTALL_DIR%\offline\vs_buildtools.exe" (
    echo  [↓] 使用离线包安装编译工具...
    "%INSTALL_DIR%\offline\vs_buildtools.exe" --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --quiet --wait
    exit /b 0
)

:: 提示
echo.
echo  ┌───────────────────────────────────────────────────────────┐
echo  │  需要安装 Visual C++ Build Tools 才能编译原生模块          │
echo  │                                                           │
echo  │  方法1（推荐）：运行 deploy\setup-buildtools.bat           │
echo  │  方法2：访问 https://aka.ms/vs/17/release/vs_buildtools.exe│
echo  └───────────────────────────────────────────────────────────┘
echo.
pause
exit /b 0


:: ════════════════════════════════════════════════════════════
::  检查/创建 .env 文件
:: ════════════════════════════════════════════════════════════
:CHECK_ENV_FILE
if exist "%INSTALL_DIR%\.env" (
    :: 检查是否已配置 API Key
    findstr /i "OPENAI_API_KEY=sk-\|ANTHROPIC_API_KEY=sk-\|ZHOUDAI_GATEWAY_TOKEN=" "%INSTALL_DIR%\.env" >nul 2>&1
    if !errorlevel! equ 0 (
        echo  [✓] 配置文件已就绪
        exit /b 0
    )
)

:: 引导配置向导
echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║           首次配置向导                                     ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.
echo  舟岱助手需要连接 AI 服务才能工作。
echo  请选择您要使用的 AI 服务：
echo.
echo  [1] DeepSeek      （国内直连，性价比最高）  ★推荐★
echo  [2] 通义千问      （阿里云，国内直连）
echo  [3] Kimi/月之暗面  （国内直连）
echo  [4] OpenAI        （需要代理）
echo  [5] Anthropic      （需要代理）
echo  [6] 暂不配置       （稍后手动编辑 .env 文件）
echo.
set /p AI_CHOICE="  请输入数字（1-6）："

:: 生成随机网关令牌
for /f %%i in ('powershell -Command "[System.Guid]::NewGuid().ToString('N').Substring(0,32)"') do set "GATEWAY_TOKEN=%%i"

:: 创建基础 .env
(
echo # 舟岱自动化小助手 配置文件
echo # 修改后重新运行 start.bat 生效
echo.
echo # 网关安全令牌（首次访问Web控制台需要）
echo ZHOUDAI_GATEWAY_TOKEN=%GATEWAY_TOKEN%
echo OPENCLAW_GATEWAY_TOKEN=%GATEWAY_TOKEN%
echo.
echo # 数据存储目录
echo ZHOUDAI_STATE_DIR=./data/zhoudai
echo OPENCLAW_STATE_DIR=./data/zhoudai
) > "%INSTALL_DIR%\.env"

if "%AI_CHOICE%"=="6" (
    echo.
    echo  [i] 已生成配置文件模板，请编辑 .env 文件填写 API Key
    echo  [i] 网关令牌：%GATEWAY_TOKEN%
    echo.
    pause
    exit /b 0
)

if "%AI_CHOICE%"=="1" (
    echo.
    set /p DS_KEY="  请粘贴您的 DeepSeek API Key（sk-...）："
    echo DEEPSEEK_API_KEY=!DS_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_API_KEY=!DS_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://api.deepseek.com >> "%INSTALL_DIR%\.env"
    echo ZHOUDAI_DEFAULT_MODEL=deepseek-chat >> "%INSTALL_DIR%\.env"
)

if "%AI_CHOICE%"=="2" (
    echo.
    set /p QW_KEY="  请粘贴您的通义千问 API Key："
    echo QWEN_API_KEY=!QW_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_API_KEY=!QW_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1 >> "%INSTALL_DIR%\.env"
    echo ZHOUDAI_DEFAULT_MODEL=qwen-max >> "%INSTALL_DIR%\.env"
)

if "%AI_CHOICE%"=="3" (
    echo.
    set /p KIMI_KEY="  请粘贴您的 Kimi API Key："
    echo OPENAI_API_KEY=!KIMI_KEY! >> "%INSTALL_DIR%\.env"
    echo OPENAI_BASE_URL=https://api.moonshot.cn/v1 >> "%INSTALL_DIR%\.env"
    echo ZHOUDAI_DEFAULT_MODEL=moonshot-v1-8k >> "%INSTALL_DIR%\.env"
)

if "%AI_CHOICE%"=="4" (
    echo.
    set /p OAI_KEY="  请粘贴您的 OpenAI API Key："
    echo OPENAI_API_KEY=!OAI_KEY! >> "%INSTALL_DIR%\.env"
    echo ZHOUDAI_DEFAULT_MODEL=gpt-4o >> "%INSTALL_DIR%\.env"
)

if "%AI_CHOICE%"=="5" (
    echo.
    set /p ANT_KEY="  请粘贴您的 Anthropic API Key："
    echo ANTHROPIC_API_KEY=!ANT_KEY! >> "%INSTALL_DIR%\.env"
    echo ZHOUDAI_DEFAULT_MODEL=claude-opus-4-5 >> "%INSTALL_DIR%\.env"
)

echo.
echo  [✓] 配置完成！网关令牌已保存到 .env 文件
echo.
echo  ┌───────────────────────────────────────────────────┐
echo  │  ★ 重要：请记录您的网关令牌 ★                    │
echo  │  %GATEWAY_TOKEN%  │
echo  │  首次访问控制台时需要输入此令牌                   │
echo  └───────────────────────────────────────────────────┘
echo.
pause

exit /b 0


:: ════════════════════════════════════════════════════════════
::  设置国内 npm/pnpm 镜像
:: ════════════════════════════════════════════════════════════
:SET_NPM_MIRROR
npm config set registry https://registry.npmmirror.com >nul 2>&1
npm config set disturl https://npmmirror.com/mirrors/node >nul 2>&1
npm config set electron_mirror https://npmmirror.com/mirrors/electron/ >nul 2>&1
npm config set sharp_dist_base_url https://npmmirror.com/mirrors/sharp-libvips/ >nul 2>&1
npm config set node_sqlite3_binary_host_mirror https://npmmirror.com/mirrors >nul 2>&1
pnpm config set registry https://registry.npmmirror.com >nul 2>&1
exit /b 0


:: ════════════════════════════════════════════════════════════
::  等待服务启动
:: ════════════════════════════════════════════════════════════
:WAIT_FOR_SERVICE
set "RETRY=0"
:WAIT_LOOP
set /a RETRY+=1
if %RETRY% GTR 30 (
    echo  [!] 服务启动超时，请检查日志文件
    goto :OPEN_BROWSER
)
curl -s --max-time 2 http://localhost:18788 >nul 2>&1
if %errorlevel% equ 0 goto :SERVICE_READY
timeout /t 2 /nobreak >nul
<nul set /p =.
goto :WAIT_LOOP

:SERVICE_READY
echo.
echo  [✓] 服务已就绪！
exit /b 0


:: ════════════════════════════════════════════════════════════
::  刷新 PATH 环境变量
:: ════════════════════════════════════════════════════════════
:REFRESH_PATH
for /f "tokens=2*" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%b"
set "PATH=!SYS_PATH!;!USR_PATH!;%PATH%"
exit /b 0


:: ════════════════════════════════════════════════════════════
::  打开浏览器
:: ════════════════════════════════════════════════════════════
:OPEN_BROWSER
echo.
echo  ════════════════════════════════════════════════════════════
echo   舟岱自动化小助手已启动！
echo.
echo   访问地址：http://localhost:18788
echo.
echo   首次访问需输入网关令牌（在 .env 文件中查看）
echo  ════════════════════════════════════════════════════════════
echo.

:: 延迟2秒后打开浏览器
timeout /t 2 /nobreak >nul
start "" "http://localhost:18788"

echo  按任意键关闭此窗口（服务继续在后台运行）
pause >nul
exit /b 0


:: ════════════════════════════════════════════════════════════
::  启动失败处理
:: ════════════════════════════════════════════════════════════
:SETUP_FAILED
echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║  启动失败！请按以下步骤排查：                             ║
echo  ║                                                           ║
echo  ║  1. 确认以管理员身份运行                                  ║
echo  ║  2. 检查网络连接                                          ║
echo  ║  3. 查看日志文件：logs\gateway.log                        ║
echo  ║  4. 参阅安装说明：deploy\员工安装说明.md                  ║
echo  ║  5. 联系运维人员并提供日志截图                            ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.
pause
exit /b 1

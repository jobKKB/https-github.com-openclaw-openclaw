@echo off
chcp 65001 >nul
title 舟岱自动化小助手 - 一键启动

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║       舟岱自动化小助手 - 一键启动程序           ║
echo  ║       Zhoudai Automation Assistant               ║
echo  ╚══════════════════════════════════════════════════╝
echo.

:: ============================================================
:: 第一步：检测 Docker Desktop 是否安装
:: ============================================================
echo [1/5] 检测 Docker Desktop...
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ❌ 未检测到 Docker Desktop！
    echo.
    echo  请先安装 Docker Desktop：
    echo  下载地址：https://www.dockerdesktop.cn  （国内镜像）
    echo  或官网：https://www.docker.com/products/docker-desktop
    echo.
    echo  安装完成后请重新运行此脚本。
    echo.
    pause
    exit /b 1
)
echo  ✅ Docker 已安装

:: ============================================================
:: 第二步：检测 Docker 服务是否运行
:: ============================================================
echo [2/5] 检测 Docker 服务状态...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  ⚠️  Docker 服务未启动，正在尝试启动...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    echo  请等待 Docker Desktop 完全启动后（约30秒），再重新运行此脚本
    echo.
    timeout /t 5 >nul
    pause
    exit /b 1
)
echo  ✅ Docker 服务正常运行

:: ============================================================
:: 第三步：首次配置（仅首次运行需要）
:: ============================================================
echo [3/5] 检查配置文件...

if not exist ".env" (
    echo.
    echo  ══════════════════════════════════════════════════
    echo   首次启动配置向导
    echo  ══════════════════════════════════════════════════
    echo.
    echo  需要配置您的 AI API 密钥才能使用。
    echo  支持以下服务（至少配置一个）：
    echo.
    echo   [1] DeepSeek（推荐国内用户）
    echo   [2] OpenAI（需要梯子）
    echo   [3] 通义千问 / 其他 OpenAI 兼容服务
    echo   [4] 暂时跳过（后续手动配置）
    echo.
    set /p AI_CHOICE="请选择 (1-4): "

    :: 创建 .env 配置文件
    echo # 舟岱自动化小助手配置文件 > .env
    echo # 生成时间: %date% %time% >> .env
    echo. >> .env

    if "%AI_CHOICE%"=="1" (
        set /p DEEPSEEK_KEY="请输入 DeepSeek API Key (https://platform.deepseek.com): "
        echo OPENAI_API_KEY=!DEEPSEEK_KEY! >> .env
        echo OPENAI_BASE_URL=https://api.deepseek.com/v1 >> .env
        echo OPENAI_MODEL=deepseek-chat >> .env
    )
    if "%AI_CHOICE%"=="2" (
        set /p OPENAI_KEY="请输入 OpenAI API Key: "
        echo OPENAI_API_KEY=!OPENAI_KEY! >> .env
    )
    if "%AI_CHOICE%"=="3" (
        set /p CUSTOM_KEY="请输入 API Key: "
        set /p CUSTOM_URL="请输入 API Base URL (如 https://dashscope.aliyuncs.com/compatible-mode/v1): "
        echo OPENAI_API_KEY=!CUSTOM_KEY! >> .env
        echo OPENAI_BASE_URL=!CUSTOM_URL! >> .env
    )

    :: 生成随机网关令牌
    for /f %%i in ('powershell -Command "[System.Guid]::NewGuid().ToString('N') + [System.Guid]::NewGuid().ToString('N')"') do set RAND_TOKEN=%%i
    echo. >> .env
    echo # 网关安全令牌（请勿泄露） >> .env
    echo ZHOUDAI_GATEWAY_TOKEN=%RAND_TOKEN% >> .env

    echo.
    echo  ✅ 配置文件已创建 (.env)
)

:: ============================================================
:: 第四步：拉取/启动 Docker 容器
:: ============================================================
echo [4/5] 启动舟岱服务...
echo.

:: 检查镜像是否已存在
docker image inspect zhoudai-assistant:latest >nul 2>&1
if %errorlevel% neq 0 (
    echo  📦 首次运行，正在加载镜像...
    :: 检查是否有离线镜像包
    if exist "zhoudai-image.tar" (
        echo  正在导入离线镜像包（首次约需1-2分钟）...
        docker load -i zhoudai-image.tar
        if %errorlevel% neq 0 (
            echo  ❌ 镜像导入失败，请检查 zhoudai-image.tar 文件是否完整
            pause
            exit /b 1
        )
        echo  ✅ 镜像导入成功
    ) else (
        echo  ⚠️  未找到离线镜像包，尝试从镜像仓库拉取...
        echo  （此步骤需要网络，约需3-10分钟）
        docker pull zhoudai-assistant:latest
        if %errorlevel% neq 0 (
            echo  ❌ 拉取失败，请联系管理员获取离线镜像包 zhoudai-image.tar
            pause
            exit /b 1
        )
    )
)

:: 启动服务
docker compose -f docker-compose.china.yml --env-file .env up -d
if %errorlevel% neq 0 (
    echo.
    echo  ❌ 启动失败，请查看上方错误信息
    echo  可尝试运行：docker compose -f docker-compose.china.yml logs
    pause
    exit /b 1
)

:: ============================================================
:: 第五步：等待服务就绪并打开浏览器
:: ============================================================
echo [5/5] 等待服务就绪...
timeout /t 5 >nul

:WAIT_LOOP
curl -s http://localhost:18788 >nul 2>&1
if %errorlevel% neq 0 (
    echo  ⏳ 服务启动中，请稍候...
    timeout /t 3 >nul
    goto WAIT_LOOP
)

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║   ✅  舟岱自动化小助手已成功启动！              ║
echo  ║                                                  ║
echo  ║   访问地址：http://localhost:18788               ║
echo  ║                                                  ║
echo  ║   提示：首次访问需配置网关令牌                  ║
echo  ║   令牌在 .env 文件的 ZHOUDAI_GATEWAY_TOKEN 中    ║
echo  ╚══════════════════════════════════════════════════╝
echo.

:: 自动打开浏览器
start http://localhost:18788

echo  按任意键关闭此窗口（服务将继续在后台运行）
pause >nul

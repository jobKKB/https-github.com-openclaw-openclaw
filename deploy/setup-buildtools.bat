@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title 安装 Visual C++ 编译工具

echo.
echo  ╔═══════════════════════════════════════════════════════════╗
echo  ║   安装 Visual C++ Build Tools                            ║
echo  ║   （编译原生 Node.js 模块必需）                           ║
echo  ╚═══════════════════════════════════════════════════════════╝
echo.
echo  此工具将安装 Microsoft Visual C++ Build Tools。
echo  这是运行舟岱助手原生模式（无Docker）的必要组件。
echo  安装大小约 3-5 GB，需要网络连接。
echo.
echo  如果您已经安装过 Visual Studio 2019/2022，则无需运行此脚本。
echo.

set /p CONFIRM="  确认安装？（Y/N）："
if /i "%CONFIRM%" neq "Y" exit /b 0

echo.
echo  [1/2] 检测安装方式...

:: 方法1：winget（Windows 10 1709+ 自带）
winget --version >nul 2>&1
if %errorlevel% equ 0 (
    echo  [↓] 通过 winget 安装 VS Build Tools 2022...
    echo  [i] 此过程需要5-15分钟，请勿关闭窗口...
    winget install Microsoft.VisualStudio.2022.BuildTools ^
        --silent ^
        --accept-package-agreements ^
        --accept-source-agreements ^
        --override "--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.Windows11SDK.22621 --includeRecommended --quiet --wait"
    
    if !errorlevel! equ 0 (
        echo  [?] 安装完成！
        echo  [i] 请重新运行 start.bat
        pause
        exit /b 0
    )
)

:: 方法2：直接下载安装程序
echo  [↓] 下载 VS Build Tools 安装程序...
set "VS_URL=https://aka.ms/vs/17/release/vs_buildtools.exe"
set "VS_SAVE=%TEMP%\vs_buildtools.exe"

powershell -Command "& { $ProgressPreference='SilentlyContinue'; Invoke-WebRequest -Uri '%VS_URL%' -OutFile '%VS_SAVE%' -UseBasicParsing }"
if %errorlevel% neq 0 (
    echo  [?] 下载失败，请手动访问以下地址下载：
    echo      https://aka.ms/vs/17/release/vs_buildtools.exe
    pause
    exit /b 1
)

echo  [↓] 启动安装程序（请在弹出的窗口中勾选"C++桌面开发"）...
"%VS_SAVE%" --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --wait

echo.
echo  [?] 安装完成！请重新运行 start.bat
pause

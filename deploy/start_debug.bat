@echo off
chcp 936 >nul 2>&1
title 舟岱 - Debug模式

echo ============================================
echo   舟岱自动化小助手 - Debug启动
echo ============================================
echo.

:: 路径设置
set "DEPLOY_DIR=%~dp0"
if "%DEPLOY_DIR:~-1%"=="\" set "DEPLOY_DIR=%DEPLOY_DIR:~0,-1%"
for %%i in ("%DEPLOY_DIR%\..") do set "INSTALL_DIR=%%~fi"

echo 脚本目录: %DEPLOY_DIR%
echo 项目根目录: %INSTALL_DIR%
echo.

:: 管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 没有管理员权限！
    echo 请关闭此窗口，右键 start_debug.bat，选"以管理员身份运行"
    pause
    exit /b 1
)
echo [OK] 管理员权限确认

:: 检查项目目录
if not exist "%INSTALL_DIR%\package.json" (
    echo.
    echo [错误] 找不到项目文件 package.json
    echo 当前检测路径: %INSTALL_DIR%
    echo.
    echo 请检查：
    echo   1. start_debug.bat 是否在项目的 deploy 子目录中？
    echo   2. 项目目录结构是否完整？
    echo.
    pause
    exit /b 1
)
echo [OK] 项目目录: %INSTALL_DIR%

:: 检测Docker
set "USE_DOCKER=0"
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    docker info >nul 2>&1
    if %errorlevel% equ 0 (
        set "USE_DOCKER=1"
        echo [OK] Docker 已检测到
    ) else (
        echo [!] Docker已安装但未运行，请启动Docker Desktop
    )
)

if "%USE_DOCKER%"=="0" (
    echo [i] 未检测到Docker，将使用原生Node.js模式
    :: 检查Node.js
    node --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo [!] Node.js未安装，将自动下载安装
    ) else (
        echo [OK] Node.js已安装
        node --version
    )
)

echo.
echo 检测完成，即将进入安装流程...
echo 注意：首次安装需要15-30分钟，请不要关闭此窗口！
echo.
pause

:: 跳转到真正的安装流程
call "%DEPLOY_DIR%\start.bat"

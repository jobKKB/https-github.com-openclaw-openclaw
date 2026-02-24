@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title 舟岱自动化小助手 - 停止服务

echo.
echo  [停止] 正在关闭舟岱自动化小助手...
echo.

set "INSTALL_DIR=%~dp0.."
pushd "%INSTALL_DIR%"
set "INSTALL_DIR=%CD%"
popd

:: 停止 Docker 容器
docker ps --filter "name=zhoudai-assistant" --format "{{.Names}}" 2>nul | findstr /i "zhoudai" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [i] 停止 Docker 容器...
    docker-compose -f "%INSTALL_DIR%\deploy\docker-compose.china.yml" down 2>nul
    docker stop zhoudai-assistant 2>nul
    echo  [✓] Docker 容器已停止
)

:: 停止原生 Node.js 进程
tasklist /fi "imagename eq node.exe" /fo list 2>nul | findstr /i "zhoudai\|openclaw\|gateway" >nul 2>&1
if %errorlevel% equ 0 (
    echo  [i] 停止 Node.js 进程...
    taskkill /f /im "node.exe" /fi "windowtitle eq zhoudai*" >nul 2>&1
)

:: 也可以通过端口停止
for /f "tokens=5" %%a in ('netstat -ano 2^>nul ^| findstr ":18788"') do (
    taskkill /f /pid %%a >nul 2>&1
)

echo.
echo  [✓] 服务已停止
echo.
pause

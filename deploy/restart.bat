@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title 舟岱自动化小助手 - 重启服务

echo.
echo  [重启] 正在重启舟岱自动化小助手...
echo.

set "INSTALL_DIR=%~dp0.."
pushd "%INSTALL_DIR%"
set "INSTALL_DIR=%CD%"
popd

:: 先停止
call "%INSTALL_DIR%\deploy\stop.bat"
timeout /t 3 /nobreak >nul

:: 再启动
call "%INSTALL_DIR%\deploy\start.bat"

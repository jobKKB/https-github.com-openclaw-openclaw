@echo off
chcp 65001 >nul
title 舟岱自动化小助手 - 停止服务

echo.
echo  正在停止舟岱自动化小助手...
docker compose -f docker-compose.china.yml down
echo.
echo  ✅ 服务已停止
echo.
pause

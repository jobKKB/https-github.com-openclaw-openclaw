@echo off
chcp 936 >nul 2>&1
echo ============================================
echo   舟岱 - 诊断工具 v1.0
echo ============================================
echo.
echo 正在检测，请稍候...
echo.
echo [1] 脚本位置: %~dp0
echo [2] 当前目录: %CD%
echo.
echo [3] 上级目录(项目根):
for %%i in ("%~dp0..") do echo     %%~fi
echo.
echo [4] Node.js:
node --version 2>nul && echo     已安装 || echo     未安装
echo.
echo [5] Docker:
docker --version 2>nul && echo     已安装 || echo     未安装
echo.
echo [6] 管理员权限:
net session >nul 2>&1 && echo     有权限 || echo     无权限（请右键以管理员运行）
echo.
echo [7] 关键文件:
for %%i in ("%~dp0..") do (
  if exist "%%~fi\package.json"  (echo     package.json  OK) else (echo     package.json  不存在！)
  if exist "%%~fi\openclaw.mjs"  (echo     openclaw.mjs  OK) else (echo     openclaw.mjs  不存在！)
  if exist "%%~fi\node_modules"  (echo     node_modules  OK) else (echo     node_modules  不存在，需安装依赖)
  if exist "%%~fi\dist"          (echo     dist目录      OK) else (echo     dist目录      不存在，需构建)
  if exist "%%~fi\.env"          (echo     .env文件      OK) else (echo     .env文件      不存在，需配置)
)
echo.
echo ============================================
echo   请截图以上内容，发给技术支持
echo ============================================
echo.
pause

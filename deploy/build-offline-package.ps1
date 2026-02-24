# 舟岱自动化小助手 - 离线安装包制作工具 (PowerShell)
# 运行要求：有网络的 Windows 电脑，需要管理员权限
# 用途：制作完整离线安装包，发给没有网络或在内网的员工电脑使用

param(
    [string]$OutputDir = "$PSScriptRoot\..\offline",
    [switch]$IncludeDocker = $false,
    [switch]$SkipNodeModules = $false
)

$ErrorActionPreference = "Stop"
chcp 65001 | Out-Null

$ROOT_DIR = Resolve-Path "$PSScriptRoot\.."
$DATE = Get-Date -Format "yyyyMMdd"
$PACKAGE_NAME = "zhoudai-offline-$DATE"
$TEMP_DIR = "$env:TEMP\$PACKAGE_NAME"
$OUTPUT_DIR = $OutputDir

Write-Host ""
Write-Host " ╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host " ║     舟岱自动化小助手 - 离线包制作工具                     ║" -ForegroundColor Cyan
Write-Host " ║     版本：v2.0                                            ║" -ForegroundColor Cyan
Write-Host " ╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host " 此脚本将制作完整的离线安装包，包含：" -ForegroundColor White
Write-Host "  [1] Node.js v22 安装包（.msi）"
Write-Host "  [2] 所有 npm/pnpm 依赖包（node_modules.tar.gz）"
if ($IncludeDocker) {
    Write-Host "  [3] Docker 镜像包（zhoudai-image.tar.gz）"
}
Write-Host ""
Write-Host " 输出目录：$OutputDir" -ForegroundColor Yellow
Write-Host ""

# 确认继续
$confirm = Read-Host " 开始制作？（Y/N）"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host " 已取消" -ForegroundColor Yellow
    exit 0
}

# 创建输出目录
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
New-Item -ItemType Directory -Force -Path $TEMP_DIR | Out-Null

Write-Host ""
Write-Host " [1/5] 下载 Node.js v22 安装包..." -ForegroundColor Green

$NODE_VERSION = "22.12.0"
$NODE_MSI = "node-v$NODE_VERSION-x64.msi"
$NODE_URL = "https://npmmirror.com/mirrors/node/v$NODE_VERSION/$NODE_MSI"
$NODE_DEST = "$OutputDir\$NODE_MSI"

if (Test-Path $NODE_DEST) {
    Write-Host " [✓] Node.js 安装包已存在，跳过下载" -ForegroundColor Green
} else {
    Write-Host " [↓] 从国内镜像下载 Node.js（约80MB）..."
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $NODE_URL -OutFile $NODE_DEST -UseBasicParsing
        Write-Host " [✓] Node.js 下载完成" -ForegroundColor Green
    } catch {
        Write-Host " [✗] Node.js 下载失败：$_" -ForegroundColor Red
        Write-Host " [i] 请手动下载放到：$NODE_DEST" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host " [2/5] 确保项目依赖已安装..." -ForegroundColor Green

# 检查项目根目录是否有 node_modules
if (-not (Test-Path "$ROOT_DIR\node_modules")) {
    Write-Host " [↓] 正在安装依赖（使用国内镜像，约需5-15分钟）..."
    
    # 设置国内镜像
    npm config set registry https://registry.npmmirror.com 2>$null
    pnpm config set registry https://registry.npmmirror.com 2>$null
    
    Push-Location $ROOT_DIR
    try {
        pnpm install --frozen-lockfile
        Write-Host " [✓] 依赖安装完成" -ForegroundColor Green
    } catch {
        Write-Host " [✗] 依赖安装失败：$_" -ForegroundColor Red
        Write-Host " [i] 请先手动运行 pnpm install 再执行此脚本" -ForegroundColor Yellow
        exit 1
    }
    Pop-Location
} else {
    Write-Host " [✓] 依赖已安装" -ForegroundColor Green
}

if (-not $SkipNodeModules) {
    Write-Host ""
    Write-Host " [3/5] 打包 node_modules（约1-5分钟）..." -ForegroundColor Green
    Write-Host " [i] 这会打包所有依赖，包含预编译的原生模块"
    
    $NM_ARCHIVE = "$OutputDir\node_modules.tar.gz"
    
    try {
        # 使用 tar 打包（Windows 10 1803+ 内置 tar）
        Push-Location $ROOT_DIR
        tar -czf $NM_ARCHIVE node_modules --exclude="node_modules/.cache" 2>&1
        $size = [math]::Round((Get-Item $NM_ARCHIVE).Length / 1MB, 0)
        Write-Host " [✓] node_modules 打包完成（约 $size MB）" -ForegroundColor Green
        Pop-Location
    } catch {
        Write-Host " [!] tar 打包失败，尝试 PowerShell 方式..." -ForegroundColor Yellow
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $NM_ZIP = "$OutputDir\node_modules.zip"
            [System.IO.Compression.ZipFile]::CreateFromDirectory("$ROOT_DIR\node_modules", $NM_ZIP)
            Rename-Item $NM_ZIP "$OutputDir\node_modules.tar.gz"
            Write-Host " [✓] node_modules 打包完成（zip格式）" -ForegroundColor Green
        } catch {
            Write-Host " [✗] 打包失败：$_" -ForegroundColor Red
        }
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host " [3/5] 跳过 node_modules 打包（-SkipNodeModules 参数）" -ForegroundColor Yellow
}

if ($IncludeDocker) {
    Write-Host ""
    Write-Host " [4/5] 导出 Docker 镜像..." -ForegroundColor Green
    
    # 检查镜像是否存在
    $imageExists = docker image inspect zhoudai-assistant:latest 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host " [↓] 本地无镜像，先构建..."
        Push-Location $ROOT_DIR
        docker build -t zhoudai-assistant:latest -f Dockerfile.china .
        Pop-Location
    }
    
    Write-Host " [↓] 导出镜像（约需 2-5 分钟，文件较大）..."
    $IMAGE_ARCHIVE = "$OutputDir\zhoudai-image.tar"
    docker save zhoudai-assistant:latest -o $IMAGE_ARCHIVE
    
    Write-Host " [↓] 压缩镜像文件..."
    tar -czf "$IMAGE_ARCHIVE.gz" -C $OutputDir "zhoudai-image.tar" 2>&1
    Remove-Item $IMAGE_ARCHIVE -Force
    
    $size = [math]::Round((Get-Item "$IMAGE_ARCHIVE.gz").Length / 1MB, 0)
    Write-Host " [✓] Docker 镜像导出完成（约 $size MB）" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host " [4/5] 跳过 Docker 镜像导出（使用 -IncludeDocker 参数可包含）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host " [5/5] 生成安装说明..." -ForegroundColor Green

# 显示离线包文件列表
Write-Host ""
Write-Host " ─────────────────────────────────────────────────────────────"
Write-Host " 离线包文件列表：" -ForegroundColor Cyan
Get-ChildItem $OutputDir | ForEach-Object {
    $sizeStr = if ($_.Length -gt 1MB) {
        "$([math]::Round($_.Length/1MB, 0)) MB"
    } else {
        "$([math]::Round($_.Length/1KB, 0)) KB"
    }
    Write-Host "   $($_.Name.PadRight(40)) $sizeStr"
}
Write-Host ""

Write-Host " ─────────────────────────────────────────────────────────────"
Write-Host " 分发给员工的方法：" -ForegroundColor Cyan
Write-Host ""
Write-Host " 方法1：直接发送 offline 目录（放在项目目录下）"
Write-Host "   将 offline\ 目录放到员工电脑的安装目录中即可"
Write-Host ""
Write-Host " 方法2：打包成 ZIP 发送"
Write-Host "   将整个项目目录（含 offline\）打包成 ZIP 发给员工"
Write-Host ""
Write-Host " 员工收到后：双击 deploy\start.bat（以管理员运行）即可" -ForegroundColor Green
Write-Host " ─────────────────────────────────────────────────────────────"
Write-Host ""
Write-Host " [✓] 离线包制作完成！" -ForegroundColor Green
Write-Host ""

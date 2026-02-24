#!/bin/bash
# ============================================================
# 舟岱自动化小助手 - 离线镜像打包工具（管理员使用）
# 在有网络的机器上运行，生成可发给员工的离线包
# ============================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$SCRIPT_DIR/dist"
VERSION=$(date +"%Y%m%d")

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║     舟岱助手 - 离线安装包制作工具（管理员）     ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

mkdir -p "$OUTPUT_DIR"

echo -e "${BOLD}[1/4]${NC} 构建 Docker 镜像（使用国内镜像源）..."
cd "$ROOT_DIR"
docker build \
    -f Dockerfile.china \
    -t zhoudai-assistant:latest \
    -t "zhoudai-assistant:$VERSION" \
    --build-arg BUILDKIT_INLINE_CACHE=1 \
    .

echo -e "${BOLD}[2/4]${NC} 导出镜像为离线包..."
PACKAGE_NAME="zhoudai-image-$VERSION.tar"
echo "  正在导出镜像（可能需要几分钟）..."
docker save zhoudai-assistant:latest | gzip > "$OUTPUT_DIR/zhoudai-image.tar.gz"
echo "  ✅ 镜像包：$OUTPUT_DIR/zhoudai-image.tar.gz"

echo -e "${BOLD}[3/4]${NC} 打包完整安装包..."
cd "$SCRIPT_DIR"
BUNDLE_NAME="zhoudai-install-$VERSION"
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME"

# 复制启动脚本
cp start.sh stop.sh 2>/dev/null "$OUTPUT_DIR/$BUNDLE_NAME/" 2>/dev/null || true
cp start.bat 2>/dev/null "$OUTPUT_DIR/$BUNDLE_NAME/" 2>/dev/null || true
cp "$ROOT_DIR/docker-compose.china.yml" "$OUTPUT_DIR/$BUNDLE_NAME/"
cp "$OUTPUT_DIR/zhoudai-image.tar.gz" "$OUTPUT_DIR/$BUNDLE_NAME/"

# 生成 README
cat > "$OUTPUT_DIR/$BUNDLE_NAME/README.txt" << 'EOF'
============================================================
    舟岱自动化小助手 - 离线安装说明
============================================================

系统要求：
  - 已安装 Docker Desktop（必须）
    Windows/Mac: https://www.dockerdesktop.cn
    Linux: curl -fsSL https://get.daocloud.io/docker | sh

安装步骤：
  1. 确保 Docker Desktop 已启动
  2. Windows 用户：双击 start.bat
     Mac/Linux 用户：chmod +x start.sh && ./start.sh

首次启动：
  - 脚本会引导您配置 AI API 密钥
  - 推荐使用 DeepSeek（国内可用，费用低）

访问地址：http://localhost:18788

常用命令（Mac/Linux）：
  ./start.sh          启动
  ./start.sh stop     停止
  ./start.sh restart  重启
  ./start.sh logs     查看日志

问题反馈：请联系内部运维团队
============================================================
EOF

chmod +x "$OUTPUT_DIR/$BUNDLE_NAME/start.sh" 2>/dev/null || true

# 打包为 zip
cd "$OUTPUT_DIR"
if command -v zip &>/dev/null; then
    zip -r "$BUNDLE_NAME.zip" "$BUNDLE_NAME/"
    echo "  ✅ 安装包：$OUTPUT_DIR/$BUNDLE_NAME.zip"
else
    tar -czf "$BUNDLE_NAME.tar.gz" "$BUNDLE_NAME/"
    echo "  ✅ 安装包：$OUTPUT_DIR/$BUNDLE_NAME.tar.gz"
fi

echo -e "${BOLD}[4/4]${NC} 打包完成！"
echo ""
echo -e "  ${GREEN}${BOLD}输出文件：${NC}"
ls -lh "$OUTPUT_DIR/" | grep -E "\.(zip|tar\.gz)$" | awk '{print "  📦 "$NF" ("$5")"}'
echo ""
echo -e "  ${YELLOW}将上述安装包发给员工，员工解压后运行 start.bat 即可${NC}"
echo ""

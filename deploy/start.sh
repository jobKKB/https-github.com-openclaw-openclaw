#!/bin/bash
# ============================================================
# 舟岱自动化小助手 - 一键启动脚本（macOS / Linux）
# ============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 脚本所在目录（即使从其他目录调用也能找到配置文件）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║       舟岱自动化小助手 - 一键启动程序           ║"
echo "  ║       Zhoudai Automation Assistant               ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================================
# 辅助函数
# ============================================================
info()    { echo -e " ${GREEN}✅${NC} $1"; }
warn()    { echo -e " ${YELLOW}⚠️ ${NC} $1"; }
error()   { echo -e " ${RED}❌${NC} $1"; }
step()    { echo -e "\n${BLUE}${BOLD}[$1]${NC} $2"; }
waiting() { echo -e " ${CYAN}⏳${NC} $1"; }

# ============================================================
# 第一步：检测 Docker
# ============================================================
step "1/5" "检测 Docker 环境..."

if ! command -v docker &>/dev/null; then
    error "未安装 Docker！"
    echo ""
    echo "  请安装 Docker："
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  macOS: https://www.docker.com/products/docker-desktop"
        echo "  或使用 Homebrew: brew install --cask docker"
    else
        echo "  Linux: curl -fsSL https://get.docker.com | sh"
        echo "  国内镜像: curl -fsSL https://get.daocloud.io/docker | sh"
    fi
    echo ""
    exit 1
fi

if ! docker info &>/dev/null; then
    error "Docker 服务未运行！"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        warn "请打开 Docker Desktop 应用，等待启动完成后重试"
        open -a Docker 2>/dev/null || true
    else
        warn "正在尝试启动 Docker 服务..."
        sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
        sleep 3
        if ! docker info &>/dev/null; then
            error "Docker 启动失败，请手动启动后重试"
            exit 1
        fi
    fi
fi

# 检查 docker compose（v2）或 docker-compose（v1）
if docker compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    error "未找到 docker compose，请更新 Docker Desktop 到最新版本"
    exit 1
fi

info "Docker 已就绪（$(docker --version | cut -d' ' -f3 | tr -d ',')）"

# ============================================================
# 第二步：首次配置
# ============================================================
step "2/5" "检查配置文件..."

if [ ! -f ".env" ]; then
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD} 首次启动配置向导${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
    echo ""
    echo "  需要配置 AI API 密钥才能使用。"
    echo "  支持以下服务（至少配置一个）："
    echo ""
    echo "   [1] DeepSeek（推荐国内用户，便宜好用）"
    echo "   [2] 通义千问（阿里云）"
    echo "   [3] OpenAI（需要梯子）"
    echo "   [4] 其他 OpenAI 兼容服务"
    echo "   [5] 暂时跳过（后续手动编辑 .env 文件）"
    echo ""
    read -p "  请选择 (1-5): " AI_CHOICE

    # 写入 .env 文件头部
    cat > .env << 'ENVEOF'
# 舟岱自动化小助手配置文件
# 修改后需重启服务：./start.sh restart
ENVEOF

    echo "# 生成时间: $(date)" >> .env
    echo "" >> .env

    case "$AI_CHOICE" in
        1)
            read -p "  请输入 DeepSeek API Key (https://platform.deepseek.com): " DS_KEY
            cat >> .env << EOF

# DeepSeek 配置
OPENAI_API_KEY=$DS_KEY
OPENAI_BASE_URL=https://api.deepseek.com/v1
OPENAI_MODEL=deepseek-chat
EOF
            ;;
        2)
            read -p "  请输入通义千问 API Key (https://dashscope.aliyun.com): " QW_KEY
            cat >> .env << EOF

# 通义千问配置
OPENAI_API_KEY=$QW_KEY
OPENAI_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
OPENAI_MODEL=qwen-max
EOF
            ;;
        3)
            read -p "  请输入 OpenAI API Key: " OAI_KEY
            cat >> .env << EOF

# OpenAI 配置
OPENAI_API_KEY=$OAI_KEY
EOF
            ;;
        4)
            read -p "  请输入 API Key: " CUSTOM_KEY
            read -p "  请输入 API Base URL: " CUSTOM_URL
            read -p "  请输入模型名称 (如 gpt-4): " CUSTOM_MODEL
            cat >> .env << EOF

# 自定义 AI 服务配置
OPENAI_API_KEY=$CUSTOM_KEY
OPENAI_BASE_URL=$CUSTOM_URL
OPENAI_MODEL=$CUSTOM_MODEL
EOF
            ;;
        *)
            echo "" >> .env
            echo "# 请手动填写 API Key" >> .env
            echo "# OPENAI_API_KEY=your-key-here" >> .env
            warn "已跳过，请稍后编辑 .env 文件"
            ;;
    esac

    # 生成随机网关安全令牌
    RAND_TOKEN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 48 | head -n 1)
    cat >> .env << EOF

# 网关安全令牌（请勿泄露）
ZHOUDAI_GATEWAY_TOKEN=$RAND_TOKEN
EOF

    echo ""
    info "配置文件已创建 (.env)"
    echo -e "  ${YELLOW}提示：网关令牌已自动生成，首次访问时需要输入${NC}"
fi

# ============================================================
# 第三步：加载 Docker 镜像
# ============================================================
step "3/5" "检查 Docker 镜像..."

IMAGE_EXISTS=$(docker image inspect zhoudai-assistant:latest 2>/dev/null | grep -c "Id" || echo "0")

if [ "$IMAGE_EXISTS" = "0" ]; then
    if [ -f "zhoudai-image.tar" ]; then
        echo "  📦 发现离线镜像包，正在导入（首次约需1-3分钟）..."
        docker load -i zhoudai-image.tar
        info "离线镜像导入成功"
    elif [ -f "zhoudai-image.tar.gz" ]; then
        echo "  📦 发现压缩镜像包，正在解压并导入..."
        gunzip -c zhoudai-image.tar.gz | docker load
        info "镜像导入成功"
    else
        warn "未找到离线镜像包，尝试从镜像仓库拉取..."
        echo "  （此步骤需要网络，约需5-15分钟）"
        # 尝试国内镜像仓库
        docker pull registry.cn-hangzhou.aliyuncs.com/zhoudai/assistant:latest 2>/dev/null && \
            docker tag registry.cn-hangzhou.aliyuncs.com/zhoudai/assistant:latest zhoudai-assistant:latest || \
            docker pull zhoudai-assistant:latest
        info "镜像拉取成功"
    fi
else
    info "镜像已就绪"
fi

# ============================================================
# 第四步：启动/重启服务
# ============================================================
step "4/5" "启动舟岱服务..."

ACTION="${1:-start}"

case "$ACTION" in
    stop)
        echo "  正在停止服务..."
        $COMPOSE_CMD -f docker-compose.china.yml down
        info "服务已停止"
        exit 0
        ;;
    restart)
        echo "  正在重启服务..."
        $COMPOSE_CMD -f docker-compose.china.yml restart
        info "服务已重启"
        ;;
    logs)
        $COMPOSE_CMD -f docker-compose.china.yml logs -f --tail=100
        exit 0
        ;;
    update)
        echo "  正在更新服务..."
        $COMPOSE_CMD -f docker-compose.china.yml pull
        $COMPOSE_CMD -f docker-compose.china.yml up -d
        info "服务已更新"
        ;;
    *)
        # 默认：启动
        $COMPOSE_CMD -f docker-compose.china.yml --env-file .env up -d
        ;;
esac

# ============================================================
# 第五步：等待服务就绪
# ============================================================
step "5/5" "等待服务就绪..."

MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s http://localhost:18788 >/dev/null 2>&1; then
        break
    fi
    waiting "启动中 (${WAITED}s)..."
    sleep 3
    WAITED=$((WAITED + 3))
done

echo ""
if curl -s http://localhost:18788 >/dev/null 2>&1; then
    GATEWAY_TOKEN=$(grep "ZHOUDAI_GATEWAY_TOKEN" .env | cut -d'=' -f2)
    echo -e "${GREEN}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   ✅  舟岱自动化小助手已成功启动！              ║"
    echo "  ║                                                  ║"
    echo "  ║   访问地址：http://localhost:18788               ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ${YELLOW}网关令牌（首次访问需要输入）：${NC}"
    echo -e "  ${CYAN}${GATEWAY_TOKEN}${NC}"
    echo ""
    echo -e "  ${BOLD}常用命令：${NC}"
    echo "  ./start.sh          # 启动服务"
    echo "  ./start.sh stop     # 停止服务"
    echo "  ./start.sh restart  # 重启服务"
    echo "  ./start.sh logs     # 查看日志"
    echo "  ./start.sh update   # 更新到最新版"
    echo ""

    # macOS 自动打开浏览器
    if [[ "$OSTYPE" == "darwin"* ]]; then
        open "http://localhost:18788" 2>/dev/null || true
    fi
else
    warn "服务启动超时，请运行以下命令查看日志："
    echo "  ./start.sh logs"
fi

#!/bin/bash

# ==============================================================================
# GoClaw Setup Wizard — Professional VPS Deployment
# Author: Phan Trung (EduQuiz R&D)
# Version: 1.1.0
# Description: One-command setup with security hardening for GoClaw AI Agent
# Usage: sudo bash setup.sh [--non-interactive] [--skip-ssl] [--skip-firewall]
# ==============================================================================

set -euo pipefail

# ==================== CONFIG ====================
GOCLAW_VERSION="latest"
MIN_RAM_MB=512
MIN_DISK_GB=5
REQUIRED_CMDS=("curl" "openssl")

# ==================== COLORS ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ==================== FLAGS ====================
NON_INTERACTIVE=false
SKIP_SSL=false
SKIP_FIREWALL=false
ERRORS=0

for arg in "$@"; do
    case $arg in
        --non-interactive) NON_INTERACTIVE=true ;;
        --skip-ssl)        SKIP_SSL=true ;;
        --skip-firewall)   SKIP_FIREWALL=true ;;
        --help|-h)
            echo "Usage: sudo bash setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --non-interactive   Skip all prompts, use defaults + env vars"
            echo "  --skip-ssl          Skip Nginx + SSL certificate setup"
            echo "  --skip-firewall     Skip UFW firewall configuration"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
    esac
done

# ==================== HELPERS ====================
header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

step() { echo -e "\n${BLUE}▶ $1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "  ${DIM}ℹ $1${NC}"; }

prompt() {
    local prompt_text=$1
    local default_val=$2
    local var_name=$3
    local is_secret=${4:-false}

    if $NON_INTERACTIVE; then
        eval "$var_name='$default_val'"
        return
    fi

    if [ -n "$default_val" ]; then
        if [ "$is_secret" = true ]; then
            echo -e -n "  ${CYAN}$prompt_text [****]: ${NC}"
        else
            echo -e -n "  ${CYAN}$prompt_text [$default_val]: ${NC}"
        fi
    else
        echo -e -n "  ${CYAN}$prompt_text: ${NC}"
    fi

    if [ "$is_secret" = true ]; then
        read -rs input_val
        echo ""
    else
        read -r input_val
    fi

    if [ -z "$input_val" ]; then
        eval "$var_name='$default_val'"
    else
        eval "$var_name='$input_val'"
    fi
}

confirm() {
    if $NON_INTERACTIVE; then return 0; fi
    local prompt_text=$1
    echo -e -n "  ${YELLOW}$prompt_text (y/N): ${NC}"
    read -r answer
    [[ "$answer" =~ ^[yY]$ ]]
}

gen_password() { openssl rand -base64 "${1:-24}" | tr -d '/+=' | head -c "${1:-24}"; }
gen_hex()      { openssl rand -hex "${1:-16}"; }

# ==================== BANNER ====================
clear
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   GoClaw Setup Wizard  v1.1.0                ║"
echo "  ║   AI Agent Orchestration Platform             ║"
echo "  ╚══════════════════════════════════════════════╝"
echo -e "${NC}"

# ==================== PHASE 1: SYSTEM CHECK ====================
header "Phase 1/6 — System Requirements"

# Root check
step "Root privileges"
if [ "$EUID" -ne 0 ]; then
    fail "Script phải chạy bằng root. Dùng: sudo bash setup.sh"
    exit 1
fi
ok "Running as root"

# OS check
step "Operating System"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ok "$NAME $VERSION_ID ($PRETTY_NAME)"
else
    warn "Không xác định được OS. Script được test trên Ubuntu 22.04+."
fi

# RAM check
step "RAM (tối thiểu ${MIN_RAM_MB}MB)"
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM_MB" -ge "$MIN_RAM_MB" ]; then
    ok "${TOTAL_RAM_MB}MB RAM"
else
    fail "Chỉ có ${TOTAL_RAM_MB}MB RAM. Cần tối thiểu ${MIN_RAM_MB}MB."
fi

# Disk check
step "Disk (tối thiểu ${MIN_DISK_GB}GB)"
AVAIL_DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
if [ "$AVAIL_DISK_GB" -ge "$MIN_DISK_GB" ]; then
    ok "${AVAIL_DISK_GB}GB available"
else
    fail "Chỉ còn ${AVAIL_DISK_GB}GB. Cần tối thiểu ${MIN_DISK_GB}GB."
fi

# Required commands
step "Required commands"
for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        warn "$cmd chưa có — sẽ cài tự động"
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    fail "Có $ERRORS lỗi. Vui lòng fix trước khi tiếp tục."
    exit 1
fi

# ==================== PHASE 2: INSTALL DEPENDENCIES ====================
header "Phase 2/6 — Install Dependencies"

step "apt packages (curl, openssl)"
apt-get update -qq &>/dev/null
apt-get install -y -qq curl openssl ca-certificates &>/dev/null
ok "System packages OK"

step "Docker Engine"
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    ok "Docker $DOCKER_VER (đã cài)"
else
    info "Đang cài Docker..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh &>/dev/null
    rm -f /tmp/get-docker.sh
    systemctl enable docker --now &>/dev/null
    ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
fi

step "Docker Compose"
if docker compose version &>/dev/null; then
    ok "Docker Compose $(docker compose version --short)"
else
    info "Đang cài Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin &>/dev/null
    ok "Docker Compose $(docker compose version --short)"
fi

# ==================== PHASE 3: CONFIGURATION WIZARD ====================
header "Phase 3/6 — Configuration"

echo -e "  Nhập thông tin cấu hình (Enter = dùng giá trị mặc định):\n"

# Install directory
INSTALL_DIR="${GOCLAW_INSTALL_DIR:-/opt/goclaw}"
prompt "📁 Thư mục cài đặt" "$INSTALL_DIR" "INSTALL_DIR"

# Database
DB_USER="${GOCLAW_DB_USER:-goclaw}"
DB_PASSWORD="${GOCLAW_DB_PASSWORD:-$(gen_password 20)}"
prompt "🗄️  Database username" "$DB_USER" "DB_USER"
prompt "🔑 Database password" "$DB_PASSWORD" "DB_PASSWORD" true

# Encryption key (32 hex chars = 16 bytes)
ENCRYPTION_KEY="${GOCLAW_ENCRYPTION_KEY:-$(gen_hex 16)}"
prompt "🔐 Encryption Key (mã hoá API keys)" "$ENCRYPTION_KEY" "ENCRYPTION_KEY" true

# Port
PORT="${GOCLAW_PORT:-8080}"
prompt "🌐 Dashboard port" "$PORT" "PORT"

# Admin password (for first login)
ADMIN_PASSWORD="$(gen_password 16)"

echo -e "\n${YELLOW}── External APIs (tuỳ chọn, có thể thêm sau trên Dashboard) ──${NC}"
OPENAI_API_KEY="${GOCLAW_OPENAI_KEY:-}"
ANTHROPIC_API_KEY="${GOCLAW_ANTHROPIC_KEY:-}"
TELEGRAM_BOT_TOKEN="${GOCLAW_TELEGRAM_TOKEN:-}"
prompt "🤖 OpenAI API Key (sk-...)" "$OPENAI_API_KEY" "OPENAI_API_KEY" true
prompt "🧠 Anthropic API Key (sk-ant-...)" "$ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY" true
prompt "📱 Telegram Bot Token" "$TELEGRAM_BOT_TOKEN" "TELEGRAM_BOT_TOKEN" true

# ==================== PHASE 4: DEPLOY ====================
header "Phase 4/6 — Deploy GoClaw"

step "Tạo thư mục"
mkdir -p "$INSTALL_DIR/workspaces"
mkdir -p "$INSTALL_DIR/backups"
ok "$INSTALL_DIR"

step "Tạo .env (permissions 600)"
cat > "$INSTALL_DIR/.env" << ENVFILE
# =============================================
# GoClaw Configuration — Auto-generated
# Generated: $(date -Iseconds)
# =============================================

# Database
DB_HOST=postgres
DB_PORT=5432
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=goclaw
GOCLAW_POSTGRES_DSN=postgres://${DB_USER}:${DB_PASSWORD}@postgres:5432/goclaw?sslmode=disable

# Security — ENCRYPTION_KEY mã hoá tất cả API keys trong DB
# KHÔNG ĐƯỢC thay đổi sau khi đã cấu hình agents, sẽ mất API keys!
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Server
PORT=${PORT}
GIN_MODE=release

# API Keys (có thể thêm/sửa trên Dashboard sau)
OPENAI_API_KEY=${OPENAI_API_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Telegram
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
ENVFILE
chmod 600 "$INSTALL_DIR/.env"
ok ".env (root-only readable)"

step "Tạo docker-compose.yml"
cat > "$INSTALL_DIR/docker-compose.yml" << 'COMPOSEFILE'
services:
  postgres:
    image: postgres:15-alpine
    container_name: goclaw-db
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - goclaw-internal
    # SECURITY: Không expose port ra ngoài

  goclaw:
    image: ghcr.io/nextlevelbuilder/goclaw:latest
    container_name: goclaw-app
    ports:
      - "127.0.0.1:${PORT}:${PORT}"
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    volumes:
      - ./workspaces:/app/workspaces
    networks:
      - goclaw-internal

volumes:
  postgres_data:
    driver: local

networks:
  goclaw-internal:
    driver: bridge
COMPOSEFILE
ok "docker-compose.yml"

step "Tạo backup script"
cat > "$INSTALL_DIR/backup.sh" << 'BACKUPSCRIPT'
#!/bin/bash
# GoClaw Database Backup
BACKUP_DIR="$(dirname "$0")/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/goclaw_${TIMESTAMP}.sql.gz"

cd "$(dirname "$0")"
docker compose exec -T postgres pg_dump -U goclaw goclaw | gzip > "$BACKUP_FILE"

# Giữ lại 7 bản backup gần nhất
ls -t "$BACKUP_DIR"/goclaw_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
echo "✓ Backup: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
BACKUPSCRIPT
chmod +x "$INSTALL_DIR/backup.sh"
ok "backup.sh (giữ 7 bản gần nhất)"

step "Pull Docker images"
cd "$INSTALL_DIR"
docker compose pull 2>&1 | tail -1
ok "Images pulled"

step "Khởi động services"
docker compose up -d 2>&1 | tail -2

# Wait for health
echo -e "  ${DIM}Đợi PostgreSQL khởi động...${NC}"
for i in $(seq 1 30); do
    if docker compose exec -T postgres pg_isready -U "$DB_USER" -d goclaw &>/dev/null 2>&1; then
        ok "PostgreSQL healthy"
        break
    fi
    sleep 1
    if [ "$i" -eq 30 ]; then
        fail "PostgreSQL không khởi động được trong 30s"
    fi
done

# Check GoClaw app
sleep 3
if docker compose ps --format '{{.Status}}' goclaw 2>/dev/null | grep -qi "up"; then
    ok "GoClaw app running"
else
    warn "GoClaw container chưa ổn định. Kiểm tra: docker compose logs goclaw"
fi

# ==================== PHASE 5: SECURITY HARDENING ====================
header "Phase 5/6 — Security Hardening"

# 5A: Nginx Reverse Proxy + SSL
if ! $SKIP_SSL; then
    step "Nginx Reverse Proxy + SSL"

    SETUP_SSL=false
    DOMAIN=""

    if ! $NON_INTERACTIVE; then
        if confirm "Cài Nginx + SSL (HTTPS) cho Dashboard?"; then
            SETUP_SSL=true
            prompt "🌐 Tên miền (VD: goclaw.example.com)" "" "DOMAIN"
        fi
    fi

    if $SETUP_SSL && [ -n "$DOMAIN" ]; then
        info "Đang cài Nginx + Certbot..."
        apt-get install -y -qq nginx certbot python3-certbot-nginx &>/dev/null

        # Tạo Nginx config
        cat > "/etc/nginx/sites-available/goclaw" << NGINXCONF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
    }
}
NGINXCONF

        ln -sf /etc/nginx/sites-available/goclaw /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        nginx -t &>/dev/null && systemctl reload nginx

        # Request SSL cert
        info "Đang xin SSL certificate cho $DOMAIN..."
        if certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos \
            --email "admin@${DOMAIN}" --redirect 2>/dev/null; then
            ok "SSL certificate OK — https://$DOMAIN"
        else
            warn "SSL thất bại. Kiểm tra DNS trỏ về IP server chưa."
            info "Retry sau: sudo certbot --nginx -d $DOMAIN"
        fi
    else
        info "Bỏ qua SSL. Dashboard chạy HTTP trên port $PORT."
        warn "⚠ KHÔNG dùng HTTP trên production — API keys sẽ bị lộ!"
    fi
else
    info "Bỏ qua SSL (--skip-ssl)"
fi

# 5B: Firewall (UFW)
if ! $SKIP_FIREWALL; then
    step "Firewall (UFW)"

    SETUP_FW=false
    if ! $NON_INTERACTIVE; then
        if confirm "Cấu hình UFW firewall?"; then
            SETUP_FW=true
        fi
    fi

    if $SETUP_FW; then
        apt-get install -y -qq ufw &>/dev/null

        ufw --force reset &>/dev/null
        ufw default deny incoming &>/dev/null
        ufw default allow outgoing &>/dev/null
        ufw allow ssh &>/dev/null
        ufw allow 80/tcp &>/dev/null
        ufw allow 443/tcp &>/dev/null

        # Chỉ mở port GoClaw nếu KHÔNG có Nginx
        if [ -z "$DOMAIN" ]; then
            ufw allow "$PORT"/tcp &>/dev/null
            info "Mở port $PORT (không có Nginx)"
        fi

        ufw --force enable &>/dev/null
        ok "UFW enabled: SSH, HTTP, HTTPS"
        info "Port $PORT chỉ listen 127.0.0.1 (không expose ra internet)"
    else
        info "Bỏ qua firewall."
    fi
else
    info "Bỏ qua firewall (--skip-firewall)"
fi

# 5C: Cron backup
step "Automated backup (daily)"
CRON_JOB="0 3 * * * ${INSTALL_DIR}/backup.sh >> ${INSTALL_DIR}/backups/cron.log 2>&1"
(crontab -l 2>/dev/null | grep -v "goclaw"; echo "$CRON_JOB") | crontab -
ok "Backup tự động lúc 3:00 AM hàng ngày"

# ==================== PHASE 6: HEALTH CHECK & SUMMARY ====================
header "Phase 6/6 — Health Check & Summary"

step "Service status"
CONTAINERS=$(docker compose -f "$INSTALL_DIR/docker-compose.yml" ps --format '{{.Name}} → {{.Status}}' 2>/dev/null)
echo "$CONTAINERS" | while read -r line; do
    ok "$line"
done

step "Network"
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "N/A")
ok "Public IP: $SERVER_IP"

# Final summary
echo ""
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║            🎉  GoClaw Deployed Successfully!  🎉            ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ -n "$DOMAIN" ]; then
    echo -e "  ${BOLD}🌐 Dashboard:${NC}  ${GREEN}https://$DOMAIN${NC}"
else
    echo -e "  ${BOLD}🌐 Dashboard:${NC}  ${YELLOW}http://$SERVER_IP:$PORT${NC}"
fi
echo -e "  ${BOLD}📁 Install Dir:${NC} $INSTALL_DIR"
echo -e "  ${BOLD}🔑 DB Password:${NC} ${DIM}(saved in $INSTALL_DIR/.env)${NC}"
echo ""

echo -e "  ${BOLD}Quick Commands:${NC}"
echo -e "    ${CYAN}cd $INSTALL_DIR${NC}"
echo -e "    ${CYAN}docker compose logs -f goclaw${NC}    ${DIM}# Xem logs${NC}"
echo -e "    ${CYAN}docker compose restart${NC}            ${DIM}# Restart${NC}"
echo -e "    ${CYAN}./backup.sh${NC}                       ${DIM}# Backup DB${NC}"
echo ""

echo -e "  ${BOLD}Next Steps:${NC}"
echo "    1. Mở Dashboard → Tạo tài khoản Admin"
echo "    2. Tạo Agent COO (chọn model gpt-4o)"
echo "    3. Kết nối Telegram Bot → Chat với COO"
echo ""

echo -e "  ${BOLD}${RED}⚠ Security Reminders:${NC}"
echo "    • KHÔNG commit .env lên Git (chứa API keys + DB password)"
echo "    • KHÔNG đổi ENCRYPTION_KEY sau khi đã tạo agents"
echo "    • Backup tự động chạy 3:00 AM → $INSTALL_DIR/backups/"
echo ""
echo -e "  ${DIM}Setup completed at $(date +'%Y-%m-%d %H:%M:%S %Z')${NC}"
echo ""

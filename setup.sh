#!/bin/bash

# ==============================================================================
# GoClaw Setup Wizard — VPS Production Deployment
# Author: Phan Trung (EduQuiz R&D)
# Version: 2.0.0
# Description: One-command setup aligned with official GoClaw docs (Cách 4: VPS)
#              Clones repo, builds from source, includes Dashboard + Gateway.
# Usage: sudo bash setup.sh [--non-interactive] [--skip-ssl] [--skip-firewall]
# Docs:  https://docs.goclaw.sh/#installation
# ==============================================================================

set -euo pipefail

# ==================== CONFIG ====================
GOCLAW_REPO="https://github.com/nextlevelbuilder/goclaw.git"
DEFAULT_INSTALL_DIR="$(pwd)"
MIN_RAM_MB=2048
MIN_DISK_GB=10
REQUIRED_CMDS=("curl" "openssl" "git")
GATEWAY_PORT=18790
DASHBOARD_PORT=3000

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
        --reset)
            echo -e "${YELLOW}RESET MODE — Xoa cai dat cu va setup lai${NC}"
            INSTALL_DIR="${GOCLAW_INSTALL_DIR:-$(pwd)}"
            if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
                echo -e "  Stopping containers..."
                cd "$INSTALL_DIR" && docker compose \
                    -f docker-compose.yml \
                    -f docker-compose.postgres.yml \
                    -f docker-compose.selfservice.yml \
                    down -v 2>/dev/null || true
                rm -f "$INSTALL_DIR/.env"
                echo -e "  ${GREEN}OK${NC} Containers stopped, volumes removed"
                echo -e "  ${DIM}Repo + backups giu lai${NC}"
            else
                echo -e "  Khong tim thay cai dat cu tai $INSTALL_DIR"
            fi
            echo -e "  Tiep tuc setup moi...\n"
            ;;
        --uninstall)
            echo -e "${RED}${BOLD}UNINSTALL — Go hoan toan GoClaw${NC}"
            INSTALL_DIR="${GOCLAW_INSTALL_DIR:-$(pwd)}"
            if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
                cd "$INSTALL_DIR" && docker compose \
                    -f docker-compose.yml \
                    -f docker-compose.postgres.yml \
                    -f docker-compose.selfservice.yml \
                    down -v --rmi all 2>/dev/null || true
            fi
            # Remove Nginx config
            rm -f /etc/nginx/sites-enabled/goclaw /etc/nginx/sites-available/goclaw 2>/dev/null
            nginx -t &>/dev/null && systemctl reload nginx 2>/dev/null || true
            # Remove cron
            (crontab -l 2>/dev/null | grep -v "goclaw") | crontab - 2>/dev/null || true
            # Remove directory
            echo -e "  Xoa $INSTALL_DIR ..."
            rm -rf "$INSTALL_DIR"
            echo -e "  ${GREEN}OK${NC} GoClaw da duoc go hoan toan."
            exit 0
            ;;
        --upgrade)
            echo -e "${CYAN}${BOLD}UPGRADE — Cap nhat GoClaw len phien ban moi nhat${NC}"
            INSTALL_DIR="${GOCLAW_INSTALL_DIR:-$(pwd)}"
            if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
                echo -e "  ${RED}Khong tim thay GoClaw tai $INSTALL_DIR${NC}"
                exit 1
            fi
            cd "$INSTALL_DIR"
            echo -e "  Pulling latest code..."
            git pull origin main
            echo -e "  Rebuilding containers..."
            docker compose \
                -f docker-compose.yml \
                -f docker-compose.postgres.yml \
                -f docker-compose.selfservice.yml \
                up -d --build
            echo -e "  ${GREEN}OK${NC} GoClaw da cap nhat. Migration tu dong chay khi khoi dong."
            exit 0
            ;;
        --help|-h)
            echo "Usage: sudo bash setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --non-interactive   Skip all prompts, use defaults + env vars"
            echo "  --skip-ssl          Skip Nginx + SSL certificate setup"
            echo "  --skip-firewall     Skip UFW firewall configuration"
            echo "  --reset             Xoa containers/config cu, giu repo, setup lai"
            echo "  --upgrade           Pull latest + rebuild (giong git pull && docker compose up --build)"
            echo "  --uninstall         Go hoan toan GoClaw (containers, images, config, data)"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
    esac
done

# ==================== HELPERS ====================
header() {
    echo ""
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${CYAN}================================================================${NC}"
}

step() { echo -e "\n${BLUE}>> $1${NC}"; }
ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "  ${DIM}$1${NC}"; }

prompt() {
    local prompt_text="$1"
    local default_val="$2"
    local var_name="$3"
    local is_secret="${4:-false}"
    local input_val=""

    if $NON_INTERACTIVE; then
        printf -v "$var_name" '%s' "$default_val"
        return
    fi

    if [ -n "$default_val" ]; then
        if [ "$is_secret" = true ]; then
            echo -e -n "  ${CYAN}${prompt_text} [****]: ${NC}"
        else
            echo -e -n "  ${CYAN}${prompt_text} [${default_val}]: ${NC}"
        fi
    else
        echo -e -n "  ${CYAN}${prompt_text}: ${NC}"
    fi

    if [ "$is_secret" = true ]; then
        read -rs input_val < /dev/tty
        echo ""
    else
        read -r input_val < /dev/tty
    fi

    if [ -z "$input_val" ]; then
        printf -v "$var_name" '%s' "$default_val"
    else
        printf -v "$var_name" '%s' "$input_val"
    fi
}

confirm() {
    if $NON_INTERACTIVE; then return 0; fi
    local prompt_text=$1
    echo -e -n "  ${YELLOW}$prompt_text (y/N): ${NC}"
    read -r answer < /dev/tty
    [[ "$answer" =~ ^[yY]$ ]]
}

gen_password() { openssl rand -base64 "${1:-24}" | tr -d '/+=' | head -c "${1:-24}"; }
gen_hex()      { openssl rand -hex "${1:-16}"; }

# ==================== BANNER ====================
clear
echo -e "${BOLD}${GREEN}"
echo "  =============================================="
echo "    GoClaw Setup Wizard  v2.0.0"
echo "    AI Agent Orchestration Platform"
echo "    Aligned with docs.goclaw.sh"
echo "  =============================================="
echo -e "${NC}"

# ==================== PHASE 1: SYSTEM CHECK ====================
header "Phase 1/6 — System Requirements"

# Root check
step "Root privileges"
if [ "$EUID" -ne 0 ]; then
    fail "Script phai chay bang root. Dung: sudo bash setup.sh"
    exit 1
fi
ok "Running as root"

# OS check
step "Operating System"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    ok "$NAME $VERSION_ID ($PRETTY_NAME)"
else
    warn "Khong xac dinh duoc OS. Script duoc test tren Ubuntu 24.04+."
fi

# RAM check
step "RAM (toi thieu ${MIN_RAM_MB}MB = 2GB)"
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM_MB" -ge "$MIN_RAM_MB" ]; then
    ok "${TOTAL_RAM_MB}MB RAM"
else
    warn "Chi co ${TOTAL_RAM_MB}MB RAM. Khuyen nghi 2GB+ (dac biet khi build)."
fi

# Disk check
step "Disk (toi thieu ${MIN_DISK_GB}GB)"
AVAIL_DISK_GB=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
if [ "$AVAIL_DISK_GB" -ge "$MIN_DISK_GB" ]; then
    ok "${AVAIL_DISK_GB}GB available"
else
    fail "Chi con ${AVAIL_DISK_GB}GB. Can toi thieu ${MIN_DISK_GB}GB (build can nhieu disk)."
fi

# Required commands
step "Required commands"
for cmd in "${REQUIRED_CMDS[@]}"; do
    if command -v "$cmd" &>/dev/null; then
        ok "$cmd"
    else
        warn "$cmd chua co — se cai tu dong"
    fi
done

if [ $ERRORS -gt 0 ]; then
    echo ""
    fail "Co $ERRORS loi. Vui long fix truoc khi tiep tuc."
    exit 1
fi

# ==================== PHASE 2: INSTALL DEPENDENCIES ====================
header "Phase 2/6 — Install Dependencies"

step "apt packages (curl, openssl, git)"
apt-get update -qq &>/dev/null
apt-get install -y -qq curl openssl ca-certificates git &>/dev/null
ok "System packages OK"

step "Docker Engine"
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    ok "Docker $DOCKER_VER (da cai)"
else
    info "Dang cai Docker (script chinh thuc)..."
    curl -fsSL https://get.docker.com | sh &>/dev/null
    systemctl enable docker --now &>/dev/null
    ok "Docker $(docker --version | awk '{print $3}' | tr -d ',')"
fi

step "Docker Compose"
if docker compose version &>/dev/null; then
    ok "Docker Compose $(docker compose version --short)"
else
    info "Dang cai Docker Compose plugin..."
    apt-get install -y -qq docker-compose-plugin &>/dev/null
    ok "Docker Compose $(docker compose version --short)"
fi

# ==================== PHASE 3: CONFIGURATION WIZARD ====================
header "Phase 3/6 — Configuration"

echo -e "  Nhap thong tin cau hinh (Enter = dung gia tri mac dinh):\n"

# Install directory
INSTALL_DIR="${GOCLAW_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
prompt "Install directory" "$INSTALL_DIR" "INSTALL_DIR"

# Database
DB_PASSWORD="${GOCLAW_DB_PASSWORD:-$(gen_password 20)}"
prompt "Database password" "$DB_PASSWORD" "DB_PASSWORD" true

# Encryption key (32 hex chars)
ENCRYPTION_KEY="${GOCLAW_ENCRYPTION_KEY:-$(gen_hex 32)}"
prompt "Encryption Key" "$ENCRYPTION_KEY" "ENCRYPTION_KEY" true

# Gateway Token (for Dashboard login)
GATEWAY_TOKEN="${GOCLAW_GATEWAY_TOKEN:-$(gen_hex 32)}"

echo -e "\n${YELLOW}-- External APIs (optional, them sau tren Dashboard) --${NC}"
OPENROUTER_API_KEY="${GOCLAW_OPENROUTER_API_KEY:-}"
ANTHROPIC_API_KEY="${GOCLAW_ANTHROPIC_API_KEY:-}"
TELEGRAM_BOT_TOKEN="${GOCLAW_TELEGRAM_TOKEN:-}"
prompt "OpenRouter API Key (sk-or-...)" "$OPENROUTER_API_KEY" "OPENROUTER_API_KEY" true
prompt "Anthropic API Key (sk-ant-...)" "$ANTHROPIC_API_KEY" "ANTHROPIC_API_KEY" true
prompt "Telegram Bot Token" "$TELEGRAM_BOT_TOKEN" "TELEGRAM_BOT_TOKEN" true

# ==================== PHASE 4: CLONE & DEPLOY ====================
header "Phase 4/6 — Clone & Deploy GoClaw"

step "Clone GoClaw repo"
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Repo da ton tai, pulling latest..."
    cd "$INSTALL_DIR"
    git pull origin main 2>&1 | tail -1
    ok "Updated to latest"
else
    if [ -d "$INSTALL_DIR" ] && [ "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
        info "Thu muc $INSTALL_DIR da co file. Clone vao thu muc moi..."
    fi
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone "$GOCLAW_REPO" "$INSTALL_DIR" 2>&1 | tail -1
    ok "Cloned to $INSTALL_DIR"
fi
cd "$INSTALL_DIR"

step "Tao thu muc phu"
mkdir -p "$INSTALL_DIR/backups"
ok "backups/"

step "Tao .env (permissions 600)"
cat > "$INSTALL_DIR/.env" << ENVFILE
# =============================================
# GoClaw Configuration — Auto-generated by setup.sh v2.0.0
# Generated: $(date -Iseconds)
# Docs: https://docs.goclaw.sh/#configuration
# =============================================

# Database
GOCLAW_POSTGRES_DSN=postgres://goclaw:${DB_PASSWORD}@postgres:5432/goclaw?sslmode=disable
POSTGRES_USER=goclaw
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=goclaw

# Security — Ma hoa tat ca API keys trong DB
# KHONG DUOC thay doi sau khi da cau hinh agents!
GOCLAW_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Gateway Token — dung de login Dashboard
# Login: User ID = system, Password = token nay
GOCLAW_GATEWAY_TOKEN=${GATEWAY_TOKEN}

# Auto migration khi khoi dong
GOCLAW_AUTO_UPGRADE=true

# Server
GOCLAW_PORT=${GATEWAY_PORT}
GIN_MODE=release

# API Keys (co the them/sua tren Dashboard)
GOCLAW_OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
GOCLAW_ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}

# Telegram
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}

# Python runtime (cho skills dung Python)
ENABLE_PYTHON=true
ENVFILE
chmod 600 "$INSTALL_DIR/.env"
ok ".env (root-only readable)"

step "Tao backup script"
cat > "$INSTALL_DIR/backup.sh" << 'BACKUPSCRIPT'
#!/bin/bash
# GoClaw Database Backup — aligned with official docs
BACKUP_DIR="$(dirname "$0")/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/goclaw_${TIMESTAMP}.sql.gz"

cd "$(dirname "$0")"
docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
    exec -T postgres pg_dump -U goclaw goclaw | gzip > "$BACKUP_FILE"

# Giu lai 7 ban backup gan nhat
ls -t "$BACKUP_DIR"/goclaw_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
echo "[OK] Backup: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
BACKUPSCRIPT
chmod +x "$INSTALL_DIR/backup.sh"
ok "backup.sh (giu 7 ban gan nhat)"

step "Build & khoi dong services (gateway + database + dashboard)"
info "Dang build tu source... (lan dau co the mat 3-5 phut)"
docker compose \
    -f docker-compose.yml \
    -f docker-compose.postgres.yml \
    -f docker-compose.selfservice.yml \
    up -d --build 2>&1 | tail -5

# Wait for PostgreSQL
echo -e "  ${DIM}Doi PostgreSQL khoi dong...${NC}"
for i in $(seq 1 60); do
    if docker compose -f docker-compose.yml -f docker-compose.postgres.yml \
        exec -T postgres pg_isready -U goclaw -d goclaw &>/dev/null 2>&1; then
        ok "PostgreSQL healthy (pgvector enabled)"
        break
    fi
    sleep 2
    if [ "$i" -eq 60 ]; then
        fail "PostgreSQL khong khoi dong duoc trong 120s"
        info "Debug: docker compose logs postgres"
    fi
done

# Wait for GoClaw gateway
echo -e "  ${DIM}Doi GoClaw gateway...${NC}"
for i in $(seq 1 20); do
    if curl -sf http://127.0.0.1:${GATEWAY_PORT}/health &>/dev/null; then
        ok "GoClaw gateway healthy (port ${GATEWAY_PORT})"
        break
    fi
    sleep 3
    if [ "$i" -eq 20 ]; then
        warn "Gateway chua ready. Kiem tra: docker compose logs goclaw"
    fi
done

# Check Dashboard
if curl -sf http://127.0.0.1:${DASHBOARD_PORT} &>/dev/null 2>&1; then
    ok "Dashboard running (port ${DASHBOARD_PORT})"
else
    info "Dashboard dang build/khoi dong... (co the mat them 1-2 phut)"
    info "Kiem tra: docker compose -f docker-compose.selfservice.yml logs"
fi

# ==================== PHASE 5: SECURITY HARDENING ====================
header "Phase 5/6 — Security Hardening"

# 5A: Nginx Reverse Proxy + SSL
if ! $SKIP_SSL; then
    step "Nginx Reverse Proxy + SSL"

    SETUP_SSL=false
    DOMAIN=""

    if ! $NON_INTERACTIVE; then
        if confirm "Cai Nginx + SSL (HTTPS)?"; then
            SETUP_SSL=true
            prompt "Domain (e.g. goclaw.example.com)" "" "DOMAIN"
        fi
    fi

    if $SETUP_SSL && [ -n "$DOMAIN" ]; then
        info "Dang cai Nginx + Certbot..."
        apt-get install -y -qq nginx certbot python3-certbot-nginx &>/dev/null

        # Tao Nginx config — 2 server blocks (dashboard + gateway WS)
        cat > "/etc/nginx/sites-available/goclaw" << NGINXCONF
# GoClaw Dashboard
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${DASHBOARD_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# GoClaw WebSocket Gateway
server {
    listen 80;
    server_name ws.${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${GATEWAY_PORT};
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
        info "Dang xin SSL certificate cho $DOMAIN + ws.$DOMAIN..."
        if certbot --nginx -d "$DOMAIN" -d "ws.$DOMAIN" --non-interactive --agree-tos \
            --email "admin@${DOMAIN}" --redirect 2>/dev/null; then
            ok "SSL certificate OK"
        else
            warn "SSL that bai. Kiem tra DNS tro ve IP server chua."
            info "Retry: sudo certbot --nginx -d $DOMAIN -d ws.$DOMAIN"
        fi
    else
        info "Bo qua SSL. Dashboard: http://IP:$DASHBOARD_PORT, Gateway: ws://IP:$GATEWAY_PORT"
        warn "KHONG dung HTTP tren production — API keys se bi lo!"
    fi
else
    info "Bo qua SSL (--skip-ssl)"
fi

# 5B: Firewall (UFW)
if ! $SKIP_FIREWALL; then
    step "Firewall (UFW)"

    SETUP_FW=false
    if ! $NON_INTERACTIVE; then
        if confirm "Cau hinh UFW firewall?"; then
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

        # Mo port truc tiep neu KHONG co Nginx
        if [ -z "$DOMAIN" ]; then
            ufw allow "$GATEWAY_PORT"/tcp &>/dev/null
            ufw allow "$DASHBOARD_PORT"/tcp &>/dev/null
            info "Mo port $GATEWAY_PORT + $DASHBOARD_PORT (khong co Nginx)"
        fi

        ufw --force enable &>/dev/null
        ok "UFW enabled: SSH, HTTP, HTTPS"
        info "Ports $GATEWAY_PORT/$DASHBOARD_PORT chi listen 127.0.0.1 khi co Nginx"
    else
        info "Bo qua firewall."
    fi
else
    info "Bo qua firewall (--skip-firewall)"
fi

# 5C: Cron backup
step "Automated backup (daily)"
CRON_JOB="0 2 * * * cd ${INSTALL_DIR} && docker compose -f docker-compose.yml -f docker-compose.postgres.yml exec -T postgres pg_dump -U goclaw goclaw | gzip > ${INSTALL_DIR}/backups/goclaw-\$(date +\%Y\%m\%d).sql.gz"
(crontab -l 2>/dev/null | grep -v "goclaw"; echo "$CRON_JOB") | crontab -
ok "Backup tu dong luc 2:00 AM hang ngay"

# ==================== PHASE 6: HEALTH CHECK & SUMMARY ====================
header "Phase 6/6 — Health Check & Summary"

step "Service status"
cd "$INSTALL_DIR"
docker compose \
    -f docker-compose.yml \
    -f docker-compose.postgres.yml \
    -f docker-compose.selfservice.yml \
    ps --format 'table {{.Name}}\t{{.Status}}' 2>/dev/null || true

step "Network"
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || echo "N/A")
ok "Public IP: $SERVER_IP"

# Final summary
echo ""
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo -e "${BOLD}${GREEN}     GoClaw Deployed Successfully!${NC}"
echo -e "${BOLD}${GREEN}================================================================${NC}"
echo ""

if [ -n "${DOMAIN:-}" ]; then
    echo -e "  ${BOLD}Dashboard:${NC}  ${GREEN}https://$DOMAIN${NC}"
    echo -e "  ${BOLD}Gateway:${NC}    ${GREEN}wss://ws.$DOMAIN${NC}"
else
    echo -e "  ${BOLD}Dashboard:${NC}  ${YELLOW}http://$SERVER_IP:$DASHBOARD_PORT${NC}"
    echo -e "  ${BOLD}Gateway:${NC}    ${YELLOW}ws://$SERVER_IP:$GATEWAY_PORT${NC}"
fi
echo -e "  ${BOLD}Health:${NC}      ${CYAN}curl http://localhost:${GATEWAY_PORT}/health${NC}"
echo -e "  ${BOLD}Install Dir:${NC} $INSTALL_DIR"
echo ""
echo -e "  ${BOLD}Login:${NC}"
echo -e "    User ID:       ${CYAN}system${NC}"
echo -e "    Gateway Token: ${CYAN}(in $INSTALL_DIR/.env -> GOCLAW_GATEWAY_TOKEN)${NC}"
echo ""

echo -e "  ${BOLD}Commands:${NC}"
echo -e "    ${CYAN}cd $INSTALL_DIR${NC}"
COMPOSE_CMD="docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.selfservice.yml"
echo -e "    ${CYAN}${COMPOSE_CMD} logs -f goclaw${NC}     ${DIM}# Logs${NC}"
echo -e "    ${CYAN}${COMPOSE_CMD} down${NC}                ${DIM}# Stop${NC}"
echo -e "    ${CYAN}${COMPOSE_CMD} up -d --build${NC}       ${DIM}# Start/Rebuild${NC}"
echo -e "    ${CYAN}${COMPOSE_CMD} ps${NC}                  ${DIM}# Status${NC}"
echo ""

echo -e "  ${BOLD}Upgrade:${NC}"
echo -e "    ${CYAN}cd $INSTALL_DIR && git pull origin main${NC}"
echo -e "    ${CYAN}${COMPOSE_CMD} up -d --build${NC}"
echo -e "    ${DIM}Hoac: sudo bash setup.sh --upgrade${NC}"
echo ""

echo -e "  ${BOLD}Backup:${NC}"
echo -e "    ${CYAN}$INSTALL_DIR/backup.sh${NC}             ${DIM}# Manual backup${NC}"
echo -e "    ${DIM}Auto backup: 2:00 AM -> $INSTALL_DIR/backups/${NC}"
echo ""

echo -e "  ${BOLD}Next Steps:${NC}"
echo "    1. Mo Dashboard -> Login (User: system, Token: trong .env)"
echo "    2. Them LLM Provider (OpenAI / Anthropic / OpenRouter)"
echo "    3. Tao Agent dau tien -> Ket noi Telegram Bot"
echo ""

echo -e "  ${BOLD}${RED}Security Reminders:${NC}"
echo "    - KHONG commit .env len Git (chua API keys + DB password)"
echo "    - KHONG doi ENCRYPTION_KEY sau khi da tao agents"
echo "    - DNS: Tao A record cho domain + ws.domain tro ve $SERVER_IP"
echo ""
echo -e "  ${DIM}Setup completed at $(date +'%Y-%m-%d %H:%M:%S %Z')${NC}"
echo ""

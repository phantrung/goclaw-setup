#!/bin/bash

# ==============================================================================
# GoClaw Automated Setup Wizard
# Author: Manus AI
# Description: Professional interactive script to install and configure GoClaw
# ==============================================================================

# --- Colors and Formatting ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Helper Functions ---
print_step() {
    echo -e "\n${BLUE}${BOLD}==> $1${NC}"
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✖ $1${NC}"
}

prompt_input() {
    local prompt_text=$1
    local default_val=$2
    local var_name=$3
    local is_secret=$4

    if [ -n "$default_val" ]; then
        echo -e -n "${CYAN}${prompt_text} [${default_val}]: ${NC}"
    else
        echo -e -n "${CYAN}${prompt_text}: ${NC}"
    fi

    if [ "$is_secret" = true ]; then
        read -s input_val
        echo "" # Add newline after secret input
    else
        read input_val
    fi

    if [ -z "$input_val" ]; then
        eval $var_name="'$default_val'"
    else
        eval $var_name="'$input_val'"
    fi
}

generate_random_string() {
    local length=$1
    tr -dc A-Za-z0-9 </dev/urandom | head -c $length
}

# --- Pre-flight Checks ---
clear
echo -e "${BOLD}${GREEN}"
echo "  ____        ____ _               "
echo " / ___| ___  / ___| | __ ___      __"
echo "| |  _ / _ \| |   | |/ _\` \ \ /\ / /"
echo "| |_| | (_) | |___| | (_| |\ V  V / "
echo " \____|\___/ \____|_|\__,_| \_/\_/  "
echo -e "${NC}"
echo -e "${BOLD}GoClaw Interactive Setup Wizard${NC}\n"

if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (use sudo ./setup.sh)"
    exit 1
fi

# --- Step 1: Install Dependencies ---
print_step "Checking and installing dependencies..."

if ! command -v curl &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq curl
fi

if ! command -v docker &> /dev/null; then
    print_warning "Docker not found. Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
    print_success "Docker installed successfully."
else
    print_success "Docker is already installed."
fi

if ! docker compose version &> /dev/null; then
    print_warning "Docker Compose plugin not found. Installing..."
    apt-get update -qq && apt-get install -y -qq docker-compose-plugin
    print_success "Docker Compose installed successfully."
else
    print_success "Docker Compose is already installed."
fi

# --- Step 2: Configuration Wizard ---
print_step "GoClaw Configuration"
echo "Please provide the following information (press Enter to use default values):"

INSTALL_DIR="$(pwd)"
prompt_input "Installation Directory" "$INSTALL_DIR" "INSTALL_DIR" false

DB_USER="goclaw"
prompt_input "Database Username" "$DB_USER" "DB_USER" false

DEFAULT_DB_PASS=$(generate_random_string 16)
prompt_input "Database Password" "$DEFAULT_DB_PASS" "DB_PASSWORD" true

DEFAULT_ENC_KEY=$(openssl rand -hex 16)
prompt_input "Encryption Key (32 chars, used for securing API keys)" "$DEFAULT_ENC_KEY" "ENCRYPTION_KEY" true

PORT="8080"
prompt_input "Web Dashboard Port" "$PORT" "PORT" false

echo -e "\n${YELLOW}--- External APIs (Optional but recommended) ---${NC}"
prompt_input "OpenAI API Key (sk-...)" "" "OPENAI_API_KEY" true
prompt_input "Anthropic API Key (sk-ant-...)" "" "ANTHROPIC_API_KEY" true
prompt_input "Telegram Bot Token (123456:ABC...)" "" "TELEGRAM_BOT_TOKEN" true

# --- Step 3: Setup Environment ---
print_step "Setting up installation directory..."
mkdir -p "$INSTALL_DIR/workspaces"
cd "$INSTALL_DIR"
print_success "Created directory: $INSTALL_DIR"

print_step "Generating .env file..."
cat << EOF > .env
# Database Configuration
DB_HOST=postgres
DB_PORT=5432
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=goclaw

# Security
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Server
PORT=${PORT}
GIN_MODE=release

# API Keys
OPENAI_API_KEY=${OPENAI_API_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
EOF
chmod 600 .env
print_success ".env file created and secured."

print_step "Generating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 5s
      retries: 5

  goclaw:
    image: ghcr.io/nextlevelbuilder/goclaw:latest
    ports:
      - "${PORT}:${PORT}"
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    volumes:
      - ./workspaces:/app/workspaces

volumes:
  postgres_data:
EOF
print_success "docker-compose.yml created."

# --- Step 4: Start Services ---
print_step "Starting GoClaw services..."
docker compose pull
docker compose up -d

if [ $? -eq 0 ]; then
    print_success "Services started successfully!"
else
    print_error "Failed to start services. Please check docker logs."
    exit 1
fi

# --- Step 5: Final Output ---
SERVER_IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")

echo -e "\n${BOLD}${GREEN}======================================================================${NC}"
echo -e "${BOLD}${GREEN}🎉 GoClaw Installation Completed Successfully! 🎉${NC}"
echo -e "${BOLD}${GREEN}======================================================================${NC}\n"

echo -e "${BOLD}📍 Web Dashboard:${NC} http://${SERVER_IP}:${PORT}"
echo -e "${BOLD}📁 Install Dir:${NC}   ${INSTALL_DIR}"
echo -e "\n${YELLOW}Useful Commands:${NC}"
echo -e "  - View logs:    ${CYAN}cd ${INSTALL_DIR} && docker compose logs -f goclaw${NC}"
echo -e "  - Stop server:  ${CYAN}cd ${INSTALL_DIR} && docker compose down${NC}"
echo -e "  - Start server: ${CYAN}cd ${INSTALL_DIR} && docker compose up -d${NC}"
echo -e "\n${BOLD}Next Steps:${NC}"
echo "1. Open the Web Dashboard in your browser."
echo "2. Create your first Admin account."
echo "3. Go to Agents -> Create New to setup your COO bot."
echo -e "\nEnjoy your automated company! 🚀"

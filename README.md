# GoClaw Setup Wizard

> One-command VPS deployment cho GoClaw AI Agent Platform, aligned với [official docs](https://docs.goclaw.sh/#installation) (Cách 4: VPS Production).

## Quick Start

### Fresh Install

```bash
# Cách 1: Clone rồi chạy (recommended)
git clone https://github.com/phantrung/goclaw-setup.git
cd goclaw-setup
sudo bash setup.sh

# Cách 2: One-liner
curl -sL https://raw.githubusercontent.com/phantrung/goclaw-setup/main/setup.sh | sudo bash
```

### Lifecycle Commands

```bash
# Upgrade lên version mới
sudo bash setup.sh --upgrade

# Reset (xoá config, giữ repo + backups, setup lại)
sudo bash setup.sh --reset

# Gỡ hoàn toàn
sudo bash setup.sh --uninstall
```

## Architecture

Script follow theo **Cách 4: VPS (Production)** từ [docs.goclaw.sh](https://docs.goclaw.sh/#installation):

```
setup.sh v2.0.0

Phase 1: System Check     → RAM 2GB+, Disk 10GB+, OS
Phase 2: Install Deps     → Docker, Docker Compose, Git
Phase 3: Configuration    → Interactive wizard tạo .env
Phase 4: Clone & Deploy   → git clone repo → docker compose --build
Phase 5: Security         → Nginx + SSL + UFW + Auto backup
Phase 6: Health & Summary → Verify all services, hiển thị thông tin
```

### Deployment Model

| Component | Cách triển khai | Port |
|-----------|----------------|------|
| **GoClaw Gateway** | Build from `docker-compose.yml` | `18790` |
| **PostgreSQL + pgvector** | Build from `docker-compose.postgres.yml` | `5432` (internal) |
| **Dashboard UI** | Build from `docker-compose.selfservice.yml` | `3000` |

> 💡 Tất cả 3 services build từ source code (clone repo), **không** pull pre-built image.

## Flags

| Flag | Mô tả |
|------|-------|
| `--non-interactive` | Skip prompts, dùng defaults + env vars |
| `--skip-ssl` | Bỏ qua Nginx + SSL setup |
| `--skip-firewall` | Bỏ qua UFW configuration |
| `--reset` | Xoá containers/config, giữ repo + backups, chạy setup lại |
| `--upgrade` | `git pull` + `docker compose --build` |
| `--uninstall` | Gỡ hết: containers, images, config, directory |

## Environment Variables

Có thể set trước để skip prompts (kết hợp `--non-interactive`):

```bash
export GOCLAW_INSTALL_DIR=/opt/goclaw
export GOCLAW_DB_PASSWORD=your_strong_password
export GOCLAW_ENCRYPTION_KEY=your_hex_key
export GOCLAW_GATEWAY_TOKEN=your_token
export GOCLAW_OPENROUTER_API_KEY=sk-or-xxx
export GOCLAW_ANTHROPIC_API_KEY=sk-ant-xxx
export GOCLAW_TELEGRAM_TOKEN=bot_token
```

## Security

### Nginx Reverse Proxy

Khi enable SSL, script tạo 2 server blocks:

| Domain | Proxy to | Purpose |
|--------|----------|---------|
| `yourdomain.com` | `localhost:3000` | Dashboard UI |
| `ws.yourdomain.com` | `localhost:18790` | WebSocket Gateway |

> ⚠️ Cần tạo 2 A records trên DNS manager trỏ về IP VPS.

### UFW Firewall

- Allow: SSH (22), HTTP (80), HTTPS (443)
- Dashboard/Gateway ports chỉ listen `127.0.0.1` khi có Nginx

### Auto Backup

- Cron job chạy `pg_dump` lúc 2:00 AM hàng ngày
- Manual: `./backup.sh`

## Dashboard Login

| Field | Value |
|-------|-------|
| **User ID** | `system` |
| **Gateway Token** | Xem file `.env` → dòng `GOCLAW_GATEWAY_TOKEN` |

## Useful Commands

```bash
cd /opt/goclaw    # hoặc thư mục bạn cài

# Compose alias (cần 3 files)
DC="docker compose -f docker-compose.yml -f docker-compose.postgres.yml -f docker-compose.selfservice.yml"

$DC logs -f goclaw         # Xem logs gateway
$DC logs -f                # Xem tất cả logs
$DC ps                     # Status
$DC down                   # Stop
$DC up -d --build          # Start/Rebuild
$DC restart goclaw         # Restart gateway only

# Health check
curl http://localhost:18790/health

# Backup manual
./backup.sh

# Upgrade
git pull origin main
$DC up -d --build
```

## Troubleshooting

| Vấn đề | Giải pháp |
|--------|-----------|
| Build fail (out of memory) | VPS cần tối thiểu 2GB RAM, khuyến nghị 4GB |
| `Port already in use` | `docker compose down` trước khi chạy lại |
| PostgreSQL unhealthy | `docker compose logs postgres` để xem lỗi |
| Dashboard 502 | Chờ 2-3 phút để build xong, hoặc check `docker compose logs` |
| SSL fail | Kiểm tra DNS A record đã trỏ về IP VPS chưa |
| `UPGRADE NEEDED` | Chạy `sudo bash setup.sh --upgrade` |
| `encryption key not set` | Kiểm tra `.env` có dòng `GOCLAW_ENCRYPTION_KEY` |

## Khác biệt so với Official Docs

| Mục | Official Docs | setup.sh |
|-----|--------------|----------|
| Cài Docker | Manual | ✅ Auto detect + install |
| Tạo .env | `./prepare-env.sh` | ✅ Interactive wizard |
| System checks | ❌ | ✅ RAM, Disk, OS |
| SSL setup | Manual Caddy/Nginx | ✅ Auto Nginx + Certbot |
| Firewall | Manual UFW commands | ✅ Auto config |
| Backup | 1-liner cron | ✅ Script + 7-day rotation |
| Reset/Uninstall | ❌ | ✅ `--reset`, `--uninstall` |
| Upgrade | Manual git pull | ✅ `--upgrade` flag |

## References

- [GoClaw Official Docs — Installation](https://docs.goclaw.sh/#installation)
- [GoClaw GitHub](https://github.com/nextlevelbuilder/goclaw)

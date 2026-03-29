# 🚀 GoClaw Setup — Professional VPS Deployment

> Deploy [GoClaw](https://github.com/nextlevelbuilder/goclaw) (AI Agent Orchestration) lên VPS với **1 lệnh**, kèm bảo mật production-grade.

![Version](https://img.shields.io/badge/Version-1.1.0-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-red?style=for-the-badge)

---

## ⚡ Quick Start (1 lệnh)

```bash
curl -sL https://raw.githubusercontent.com/phantrung/goclaw-setup/main/setup.sh | sudo bash
```

Hoặc clone về:
```bash
git clone https://github.com/phantrung/goclaw-setup.git
cd goclaw-setup
sudo bash setup.sh
```

---

## 🎯 Script làm gì?

| Phase | Nội dung |
|-------|---------|
| **1/6 — System Check** | Kiểm tra OS, RAM (≥512MB), Disk (≥5GB), root privileges |
| **2/6 — Dependencies** | Cài Docker Engine + Docker Compose nếu chưa có |
| **3/6 — Configuration** | Interactive wizard: DB credentials, Encryption Key, API keys, Telegram |
| **4/6 — Deploy** | Generate `.env` + `docker-compose.yml` → docker compose up |
| **5/6 — Security** | Nginx reverse proxy + SSL (Let's Encrypt) + UFW firewall + auto backup |
| **6/6 — Health Check** | Verify containers running, hiển thị Dashboard URL |

### 🔐 Security Hardening (v1.1 — Mới)

So sánh với script gốc:

| Tính năng | v1.0 (Manus) | v1.1 (PT) |
|-----------|:---:|:---:|
| Auto-generate strong passwords | ✅ | ✅ |
| `.env` permissions 600 | ✅ | ✅ |
| Nginx reverse proxy | ❌ | ✅ |
| SSL certificate (Let's Encrypt) | ❌ | ✅ |
| Docker port bind 127.0.0.1 only | ❌ | ✅ |
| UFW firewall configuration | ❌ | ✅ |
| PostgreSQL network isolation | ❌ | ✅ |
| Automated daily backup | ❌ | ✅ |
| Non-interactive mode (CI/CD) | ❌ | ✅ |
| Idempotent (re-runnable) | ❌ | ✅ |

---

## 📋 Yêu Cầu VPS

| Thành phần | Tối thiểu | Khuyến nghị |
|-----------|----------|-------------|
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| **RAM** | 512 MB | 1 GB |
| **CPU** | 1 vCPU | 2 vCPU |
| **Disk** | 5 GB | 20 GB |
| **Giá** | ~$4/tháng | ~$6/tháng |

Providers: DigitalOcean, Hetzner, Linode, Vultr, AWS Lightsail

---

## 🛠️ Flags & Options

```bash
sudo bash setup.sh [OPTIONS]
```

| Flag | Mô tả |
|------|-------|
| `--non-interactive` | Bỏ qua tất cả prompts, dùng defaults hoặc env vars |
| `--skip-ssl` | Không cài Nginx + SSL |
| `--skip-firewall` | Không cấu hình UFW |
| `--reset` | Xoá containers/config cũ, **giữ backups**, rồi setup lại |
| `--uninstall` | Gỡ **hoàn toàn** (containers, images, config, data, cron) |
| `-h, --help` | Hiện help |

### Reset (setup lại từ đầu)

```bash
sudo bash setup.sh --reset
```

> Xoá containers + DB data + `.env` + `docker-compose.yml`. **Giữ lại** `backups/` và `workspaces/`.

### Gỡ hoàn toàn

```bash
sudo bash setup.sh --uninstall
```

> Xoá tất cả: containers, images, volumes, Nginx config, cron job, thư mục cài đặt.

### Non-interactive mode (cho CI/CD hoặc Ansible)

```bash
export GOCLAW_DB_PASSWORD="my-strong-pass"
export GOCLAW_OPENAI_KEY="sk-..."
export GOCLAW_TELEGRAM_TOKEN="123456:ABC..."
export GOCLAW_INSTALL_DIR="/opt/goclaw"

sudo -E bash setup.sh --non-interactive --skip-ssl
```

---

## 📁 Cấu Trúc Sau Khi Cài

```
/opt/goclaw/
├── .env                    # 🔒 Config (chmod 600, root-only)
├── docker-compose.yml      # Docker services definition
├── backup.sh               # 🗄️ Script backup DB (auto cron 3:00 AM)
├── workspaces/             # 📂 File output của các Agent
└── backups/                # 💾 PostgreSQL backups (giữ 7 bản gần nhất)
    ├── goclaw_20260330_030000.sql.gz
    └── cron.log
```

---

## 🎮 Sử Dụng Sau Khi Cài

### Truy cập Dashboard

```
https://goclaw.yourdomain.com   (nếu có SSL)
http://YOUR_IP:8080             (nếu không có SSL)
```

### Các lệnh hữu ích

```bash
cd /opt/goclaw

# Xem logs
docker compose logs -f goclaw

# Restart
docker compose restart

# Stop
docker compose down

# Start
docker compose up -d

# Backup thủ công
./backup.sh

# Restore từ backup
gunzip < backups/goclaw_20260330_030000.sql.gz | docker compose exec -T postgres psql -U goclaw goclaw
```

---

## 🚨 Troubleshooting

| Vấn đề | Giải pháp |
|--------|----------|
| **Port 8080 đã dùng** | Sửa `PORT=8081` trong `.env` → `docker compose restart` |
| **SSL lỗi** | Kiểm tra DNS trỏ về IP server → `sudo certbot --nginx -d domain` |
| **Container crash** | `docker compose logs goclaw` → xem lỗi cụ thể |
| **Mất ENCRYPTION_KEY** | 🔴 Không recover được. API keys các Agent sẽ mất → phải nhập lại |
| **DB corruption** | Restore: `gunzip < backups/latest.sql.gz \| docker compose exec -T postgres psql -U goclaw goclaw` |

---

## 🔄 Update GoClaw

```bash
cd /opt/goclaw
./backup.sh                     # Backup trước
docker compose pull              # Pull image mới
docker compose up -d             # Restart với image mới
docker compose logs -f goclaw    # Verify
```

---

## 📄 License

MIT License — Free to use, modify, and distribute.

---

**Made with ❤️ by [Phan Trung](https://github.com/phantrung) — EduQuiz R&D**

*v1.1.0 — Last updated: 30/03/2026*

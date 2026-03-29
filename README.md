# 🚀 GoClaw Setup - Automated Installation Wizard

> **Xây dựng một "Công ty Tự động hóa" chỉ với 1 dòng lệnh**

![GoClaw](https://img.shields.io/badge/GoClaw-Automated%20Company-blue?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Bash](https://img.shields.io/badge/Bash-5.0+-red?style=for-the-badge)

---

## 📋 Giới Thiệu

**GoClaw Setup** là một script cài đặt tự động chuyên nghiệp giúp bạn triển khai [GoClaw](https://github.com/nextlevelbuilder/goclaw) - một nền tảng AI Agent Orchestration - trên VPS của bạn chỉ trong vài phút.

GoClaw cho phép bạn tạo ra một "công ty ảo" hoàn toàn tự động, nơi:
- **Agent COO** (Giám đốc Điều hành) nhận lệnh từ bạn qua **Telegram**.
- **Agent Workers** (Nhân viên) tự động thực thi các công việc được giao.
- Tất cả hoạt động được quản lý tập trung trên một **Shared Task Board**.

### ✨ Tại sao GoClaw?

| Tính Năng | Mô Tả |
|-----------|-------|
| **Siêu Nhẹ** | Chỉ ~35MB RAM/Agent (vs 1GB+ của OpenClaw) |
| **Tích Hợp Telegram** | Chat trực tiếp với COO, không cần Dashboard |
| **Task Board Chung** | Các Agent tự giao việc cho nhau |
| **Chi Phí Cực Rẻ** | Chạy toàn bộ công ty trên VPS 5$/tháng |
| **Dễ Mở Rộng** | Thêm Agent mới chỉ bằng vài click |

---

## 🎯 Cài Đặt Nhanh (30 giây)

### Cách 1: One-liner Installation (Khuyên dùng)

Trên VPS mới (Ubuntu 22.04+), chỉ cần chạy duy nhất 1 dòng lệnh:

```bash
curl -sL https://raw.githubusercontent.com/phantrung/goclaw-setup/main/setup.sh | sudo bash
```

### Cách 2: Manual Installation

```bash
# 1. Clone repository
git clone https://github.com/phantrung/goclaw-setup.git
cd goclaw-setup

# 2. Cấp quyền và chạy
chmod +x setup.sh
sudo ./setup.sh
```

---

## 📖 Hướng Dẫn Chi Tiết

### Bước 1: Chuẩn Bị VPS

Bạn cần một VPS với:
- **OS**: Ubuntu 22.04 LTS hoặc 24.04 LTS
- **Cấu hình tối thiểu**: 1 vCPU, 1GB RAM, 20GB SSD
- **Chi phí**: Từ $5/tháng (DigitalOcean, Linode, Hetzner, v.v.)

### Bước 2: Chạy Script Setup

SSH vào VPS với quyền `root` hoặc dùng `sudo`:

```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/goclaw-setup/main/setup.sh | sudo bash
```

Script sẽ tự động:
- ✅ Kiểm tra hệ thống
- ✅ Cài đặt Docker & Docker Compose
- ✅ Hỏi bạn các thông tin cấu hình (hoặc dùng giá trị mặc định)
- ✅ Tạo file `.env` với mật khẩu ngẫu nhiên an toàn
- ✅ Khởi động GoClaw Server

### Bước 3: Truy Cập Web Dashboard

Sau khi script chạy xong, bạn sẽ nhận được thông báo:

```
📍 Web Dashboard: http://<IP_VPS_CỦA_BẠN>:8080
```

Mở link này trong trình duyệt để:
1. Tạo tài khoản Admin đầu tiên
2. Tạo Agent COO
3. Liên kết với Telegram Bot của bạn

---

## 🎮 Cách Sử Dụng

### Ví Dụ: Phân Tích Đối Thủ Cạnh Tranh

1. **Mở Telegram**, chat với COO Bot:
   > "Anh giúp em tìm hiểu top 5 công ty HR SaaS tại Việt Nam nhé"

2. **Agent COO** sẽ:
   - Phân tích yêu cầu
   - Tạo Task cho Data_Bot (cào dữ liệu)
   - Tạo Task cho Marketing_Bot (viết báo cáo)
   - Báo lại cho bạn khi hoàn thành

3. **Bạn nhận được**:
   - File báo cáo chi tiết
   - Phân tích so sánh
   - Mọi thứ tự động, không cần can thiệp

---

## 🔧 Cấu Hình

Script sẽ hỏi bạn các thông tin sau (hoặc dùng giá trị mặc định):

| Thông Tin | Mặc Định | Mô Tả |
|-----------|----------|-------|
| Installation Directory | Thư mục hiện tại | Nơi cài đặt GoClaw |
| Database Username | `goclaw` | Tên user PostgreSQL |
| Database Password | Ngẫu nhiên 16 ký tự | Mật khẩu DB (tự tạo) |
| Encryption Key | Ngẫu nhiên 32 ký tự | Khóa mã hóa API Keys |
| Web Port | `8080` | Port Dashboard |
| OpenAI API Key | (Tùy chọn) | Để sử dụng GPT-4 |
| Telegram Bot Token | (Tùy chọn) | Để kết nối Telegram |

---

## 📁 Cấu Trúc Thư Mục

Sau khi cài đặt xong, thư mục sẽ có cấu trúc như sau:

```
goclaw-setup/
├── setup.sh                 # Script cài đặt
├── README.md               # Tài liệu này
├── .env                    # Cấu hình môi trường (được tạo tự động)
├── docker-compose.yml      # Docker Compose config (được tạo tự động)
└── workspaces/             # Thư mục lưu file của các Agent
    ├── agent1/
    ├── agent2/
    └── ...
```

---

## 🛠️ Các Lệnh Hữu Ích

Sau khi cài đặt xong, bạn có thể sử dụng các lệnh sau:

```bash
# Xem logs của GoClaw
cd /path/to/goclaw && docker compose logs -f goclaw

# Dừng server
docker compose down

# Khởi động lại server
docker compose up -d

# Xem trạng thái các container
docker compose ps

# Backup database
docker compose exec postgres pg_dump -U goclaw goclaw > backup.sql
```

---

## 🚨 Troubleshooting

### Lỗi: "Permission denied"
```bash
# Giải pháp: Chạy với sudo
sudo ./setup.sh
```

### Lỗi: "Docker not found"
```bash
# Giải pháp: Script sẽ tự cài đặt Docker, nhưng nếu vẫn lỗi:
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Port 8080 đã được sử dụng
```bash
# Giải pháp: Chỉnh sửa file .env và thay đổi PORT
nano .env
# Thay PORT=8080 thành PORT=8081 (hoặc port khác)
docker compose restart
```

---

## 📚 Tài Liệu Thêm

- [GoClaw Official Docs](https://github.com/nextlevelbuilder/goclaw)
- [Docker Documentation](https://docs.docker.com/)
- [Telegram Bot API](https://core.telegram.org/bots/api)

---

## 🤝 Đóng Góp

Nếu bạn tìm thấy lỗi hoặc có đề xuất cải thiện, vui lòng:

1. **Fork** repository này
2. Tạo một **branch** mới (`git checkout -b feature/improvement`)
3. **Commit** các thay đổi (`git commit -m 'Add improvement'`)
4. **Push** lên branch (`git push origin feature/improvement`)
5. Tạo một **Pull Request**

---

## 📄 License

Project này được cấp phép dưới **MIT License**. Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

---

## 💬 Hỗ Trợ

Nếu bạn gặp vấn đề hoặc có câu hỏi:

- 📧 **Email**: phantrung@example.com
- 💬 **GitHub**: [@phantrung](https://github.com/phantrung)
- 🐛 **Issues**: [GitHub Issues](https://github.com/phantrung/goclaw-setup/issues)

---

## 🎉 Bắt Đầu Ngay

```bash
# Chỉ cần 1 dòng lệnh!
curl -sL https://raw.githubusercontent.com/phantrung/goclaw-setup/main/setup.sh | sudo bash
```

Sau 5 phút, bạn sẽ có một "công ty ảo" hoàn toàn tự động chạy trên Telegram! 🚀

**Made with ❤️ by [Manus AI](https://manus.im) & [Phan Trung](https://github.com/phantrung)**

*Cập nhật lần cuối: 29/03/2026*

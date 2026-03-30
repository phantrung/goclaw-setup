---
name: EduQuiz Exam Search
description: |
  Tìm kiếm đề thi trắc nghiệm trên EduQuiz.vn qua Typesense API.
  Hỗ trợ search theo tên môn, filter theo trường ĐH.
  Dùng khi user yêu cầu tìm đề thi, xin link đề, hỏi có đề không.
---

# EduQuiz Exam Search

Skill giúp agent tìm đề thi trên hệ thống EduQuiz (eduquiz.vn) và trả link cho user.

## Khi nào sử dụng

Khi user nhắn tin có chứa các keyword:
- "đề thi", "link đề", "cho đề", "xin đề", "thi thử"
- "cho mình đề", "có đề không", "share đề", "link thi"
- "cho e xin", "ai có đề", "có môn", "có file"
- Hoặc bất kỳ tin nhắn nào hỏi về đề thi trắc nghiệm đại học

## Cách tìm đề

Chạy script Python đi kèm:

```bash
python3 {baseDir}/scripts/search_exam.py "<tên môn>" [--school <viết tắt trường>] [--limit <N>]
```

### Ví dụ

```bash
# Tìm đề tài chính công
python3 {baseDir}/scripts/search_exam.py "tài chính công"

# Tìm đề kinh tế vĩ mô trường UEH
python3 {baseDir}/scripts/search_exam.py "kinh tế vĩ mô" --school UEH

# Tìm đề marketing trường HUBT, lấy 10 kết quả
python3 {baseDir}/scripts/search_exam.py "marketing" --school HUBT --limit 10
```

## Viết tắt trường ĐH

| Viết tắt | Tên đầy đủ |
|----------|-----------|
| HUBT | ĐH Kinh doanh và Công nghệ Hà Nội |
| UEH | ĐH Kinh tế TP.HCM |
| NEU | ĐH Kinh tế Quốc dân |
| HUFLIT | ĐH Ngoại ngữ - Tin học TP.HCM |
| BUH | ĐH Ngân hàng TP.HCM |
| SGU | ĐH Sài Gòn |
| HVTC | Học viện Tài chính |
| EPU | ĐH Điện lực |
| TDTU | ĐH Tôn Đức Thắng |
| FTU | ĐH Ngoại thương |
| HVNH | Học viện Ngân hàng |
| TMU | ĐH Thương mại |

> Nếu user nói tên trường đầy đủ, hãy chuyển sang viết tắt tương ứng.
> Nếu user nói tên trường không có trong bảng, dùng tên đầy đủ làm --school.

## Cách trích tên môn từ tin nhắn

Tin nhắn user thường có dạng:
- "cho e xin đề **Tài chính công** 2 tín **HUBT** với ạ" → query="Tài chính công", school="HUBT"
- "ai có đề **kinh tế vĩ mô** **ĐH Kinh tế** không" → query="kinh tế vĩ mô", school="UEH"
- "xin link đề **marketing căn bản**" → query="marketing căn bản", school=""

**Quy tắc trích xuất:**
1. Bỏ các từ: "đề thi", "đề", "link", "cho", "xin", "có", "không", "ạ", "với"
2. Phần còn lại là **tên môn** (query)
3. Nếu có tên trường/viết tắt → **school**

## Format trả lời

Kết quả từ script đã được format sẵn. Gửi **nguyên văn** cho user, KHÔNG chỉnh sửa link.

Nếu không tìm thấy, trả lời:
```
Mình tìm chưa thấy đề [tên môn] nha bạn 😅
Bạn thử tìm trực tiếp tại: eduquiz.vn/kham-pha
Hoặc gõ tên môn ngắn hơn / bỏ dấu thử xem!
```

## Trường hợp user hỏi tự luận / đề cương / slide

EduQuiz CHỈ có đề trắc nghiệm. Nếu user hỏi tự luận, đề cương, slide, giáo trình:
```
EduQuiz chuyên về đề thi trắc nghiệm nha bạn, mình chưa có [tự luận/đề cương/slide].
Bạn thử tìm đề trắc nghiệm [tên môn] xem có phù hợp không nhé! 📝
```

## Tone

- Xưng hô: "mình" / "bạn" (sinh viên ngang hàng)
- Emoji: vừa phải (2-3 per message)
- Ngắn gọn, thân thiện
- Luôn kèm CTA cuối: `eduquiz.vn/kham-pha`

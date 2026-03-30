"""
GoClaw Skill: EduQuiz Exam Search
Tìm đề thi trên EduQuiz qua Typesense API.

Chạy trực tiếp:
  python3 search_exam.py "tài chính công"
  python3 search_exam.py "kinh tế vĩ mô" --school HUBT
"""

import json
import subprocess
import sys

TYPESENSE_URL = "https://typesense.eduquiz.vn/multi_search"
TYPESENSE_API_KEY = "ssLMP93b5WBExJxJwBw9QFI5LjfWFW0S"
EDUQUIZ_BASE = "https://eduquiz.vn"

SCHOOL_ALIASES = {
    "HUBT": "Đại học Kinh doanh và Công nghệ Hà Nội",
    "UEH": "Đại học Kinh tế TP.HCM",
    "NEU": "Đại học Kinh tế Quốc dân",
    "HUFLIT": "Đại học Ngoại ngữ - Tin học TP.HCM",
    "BUH": "Đại học Ngân hàng TP.HCM",
    "SGU": "Đại học Sài Gòn",
    "HVTC": "Học viện Tài chính",
    "EPU": "Đại học Điện lực",
    "TDTU": "Đại học Tôn Đức Thắng",
    "HCMUE": "Đại học Sư phạm TP.HCM",
    "FTU": "Đại học Ngoại thương",
    "HVNH": "Học viện Ngân hàng",
    "TMU": "Đại học Thương mại",
}


def search_exam(query: str, school: str = "", limit: int = 5) -> str:
    """
    Tìm đề thi trên EduQuiz.
    
    Args:
        query: Tên môn học (VD: "tài chính công", "kinh tế vĩ mô")
        school: Tên hoặc viết tắt trường ĐH. Optional.
        limit: Số kết quả tối đa (default: 5)
    
    Returns:
        Formatted text với danh sách đề thi + link
    """
    school_full = SCHOOL_ALIASES.get(school.upper(), school) if school else ""
    
    search_params = {
        "query_by": "name,alias",
        "collection": "exams",
        "q": query,
        "per_page": min(limit, 20),
        "page": 1,
    }
    
    if school_full:
        search_params["filter_by"] = f'schools:=[`{school_full}`]'
    
    body = json.dumps({"searches": [search_params]})
    url = f"{TYPESENSE_URL}?x-typesense-api-key={TYPESENSE_API_KEY}"
    
    try:
        result = subprocess.run(
            ["curl", "-s", "-X", "POST", url,
             "-H", "Content-Type: text/plain",
             "-d", body],
            capture_output=True, text=True, timeout=15
        )
        data = json.loads(result.stdout)
    except Exception as e:
        return f"Lỗi tìm kiếm: {e}"
    
    results = data.get("results", [{}])
    hits = results[0].get("hits", []) if results else []
    found = results[0].get("found", 0) if results else 0
    
    if not hits:
        msg = f'Không tìm thấy đề thi "{query}"'
        if school:
            msg += f" ({school})"
        msg += ".\n\nBạn thử:\n"
        msg += "- Gõ tên môn ngắn hơn hoặc bỏ dấu\n"
        msg += f"- Tìm trực tiếp: {EDUQUIZ_BASE}/kham-pha"
        return msg
    
    lines = []
    lines.append(f'Mình tìm được {found} đề "{query}"')
    if school:
        lines.append(f"(trường: {school_full or school})")
    lines.append(f"— hiển thị top {len(hits)}:\n")
    
    for i, hit in enumerate(hits, 1):
        doc = hit.get("document", {})
        name = doc.get("name", "N/A")
        exam_url = doc.get("exam_url", "")
        schools = doc.get("schools", [])
        total_q = doc.get("total_question", 0)
        year = doc.get("year", "")
        viewed = doc.get("viewed", 0)
        
        school_text = ", ".join(schools) if schools else ""
        meta_parts = []
        if total_q:
            meta_parts.append(f"{total_q} câu")
        if year:
            meta_parts.append(f"năm {year}")
        if viewed:
            meta_parts.append(f"{viewed:,} lượt thi")
        meta = " | ".join(meta_parts)
        
        badge = " 🔥" if i == 1 and viewed and int(viewed) > 100 else ""
        
        lines.append(f"{i}. {name}{badge}")
        if school_text:
            lines.append(f"   Trường: {school_text}")
        if meta:
            lines.append(f"   {meta}")
        lines.append(f"   👉 {exam_url}")
        lines.append("")
    
    lines.append(f"🔍 Tìm thêm: {EDUQUIZ_BASE}/kham-pha")
    
    return "\n".join(lines)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 search_exam.py <tên môn> [--school <trường>] [--limit <N>]")
        print('Example: python3 search_exam.py "tài chính công" --school HUBT')
        sys.exit(1)
    
    query = sys.argv[1]
    school = ""
    limit = 5
    
    args = sys.argv[2:]
    for i, arg in enumerate(args):
        if arg == "--school" and i + 1 < len(args):
            school = args[i + 1]
        elif arg == "--limit" and i + 1 < len(args):
            limit = int(args[i + 1])
    
    print(search_exam(query, school=school, limit=limit))

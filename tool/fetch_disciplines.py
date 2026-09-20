# 忽略编码器告警
# -*- coding: utf-8 -*-
"""抓取教育部《研究生教育学科专业目录（2022年）》并生成本地内置数据文件。

数据源：教育部官网 附件1 PDF（学位〔2022〕15号），运行时下载并解析，
产出 `assets/data/discipline_catalog.json` 随应用打包，应用运行时不联网。

依赖：pip install pypdf
用法：python tool/fetch_disciplines.py

解析规则（来自 PDF 说明页）：
- 学科门类代码两位，一级学科/专业学位类别代码四位；
- 代码第三位从“5”开始的为专业学位类别；
- 名称后加“*”的仅可授硕士专业学位，其余专业学位类别可授硕士、博士；
- 少数专业学位类别（1051/1052/1055）以“（同时设专业学位类别，代码为 XXXX）”
  形式标注在其一级学科的括号注释中，需单独提取。

输出带硬校验：14 门类 / 117 一级学科 / 67 专业学位类别 / 31 仅硕士，
与教育部公布口径不一致时直接失败，防止官网改版导致静默出错。
"""
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone, timedelta

from pypdf import PdfReader

PDF_URL = (
    "http://www.moe.gov.cn/srcsite/A22/moe_833/202209/"
    "W020220914572994461110.pdf"
)
OUT = "assets/data/discipline_catalog.json"

CATEGORY_RE = re.compile(r"^(\d{2}) ([\u4e00-\u9fff]+)$")
ENTRY_RE = re.compile(r"^(\d{4})\s+(.+?)(\*)?$")
PAGE_NO_RE = re.compile(r"^—\s*\d+\s*—$")
CHILD_PROFESSIONAL_RE = re.compile(r"同时设专业学位类别，?代码为\s*(\d{4})")


def download_pdf(path: str) -> None:
    req = urllib.request.Request(
        PDF_URL,
        headers={
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        },
    )
    with urllib.request.urlopen(req, timeout=60) as resp, open(path, "wb") as f:
        f.write(resp.read())


def parse(path: str):
    reader = PdfReader(path)
    categories = []
    current = None
    last_item = None
    for page in reader.pages[2:]:  # 跳过封面与说明页
        for raw in page.extract_text().splitlines():
            line = raw.strip()
            if not line or PAGE_NO_RE.match(line):
                continue
            cat = CATEGORY_RE.match(line)
            if cat:
                current = {"code": cat[1], "name": cat[2], "items": []}
                categories.append(current)
                last_item = None
                continue
            ent = ENTRY_RE.match(line)
            if ent:
                if current is None:
                    continue  # 说明页等前置内容
                last_item = {
                    "code": ent[1],
                    "name": ent[2].strip(),
                    "star": ent[3] is not None,
                }
                current["items"].append(last_item)
                continue
            # 表格内的折行（括号注释被 pypdf 拆开），拼回上一条目
            if last_item is not None:
                last_item["name"] = (last_item["name"] + line).strip()
    return categories


def build(categories):
    """拆分名称与注释，提取括号中的附属专业学位类别，归一化输出结构。"""
    out = []
    academic_total = 0
    professional_total = 0
    master_only_total = 0
    seen = set()
    for cat in categories:
        items = []
        for raw in cat["items"]:
            name = raw["name"]
            note = None
            if "（" in name and name.endswith("）"):
                name, _, rest = name.partition("（")
                note = rest.rstrip("）").strip()
            is_professional = raw["code"][2] >= "5"
            children = []
            if note:
                children = CHILD_PROFESSIONAL_RE.findall(note)
            if is_professional:
                items.append(
                    {
                        "code": raw["code"],
                        "name": name,
                        "type": "professional",
                        "doctoral": not raw["star"],
                    }
                )
                professional_total += 1
                if raw["star"]:
                    master_only_total += 1
            else:
                items.append(
                    {
                        "code": raw["code"],
                        "name": name,
                        "type": "academic",
                        **({"note": note} if note else {}),
                    }
                )
                academic_total += 1
            for child_code in children:
                items.append(
                    {
                        "code": child_code,
                        "name": name,
                        "type": "professional",
                        "doctoral": True,
                    }
                )
                professional_total += 1
        # 门类内按代码排序：一级学科（第三位小于5）在前，专业学位类别在后
        items.sort(key=lambda i: (i["code"][2] >= "5", i["code"]))
        for item in items:
            if item["code"] in seen:
                raise SystemExit(f"重复代码：{item['code']}")
            seen.add(item["code"])
        out.append({"code": cat["code"], "name": cat["name"], "items": items})
    return out, academic_total, professional_total, master_only_total


def main():
    pdf_path = "discipline_catalog_2022.pdf"
    download_pdf(pdf_path)
    categories = parse(pdf_path)
    data, academic, professional, master_only = build(categories)

    # 硬校验：与教育部公布口径一致（14 门类 / 117 一级学科 / 67 专业学位类别，
    # 其中仅可授硕士的 31 个）。官网文件结构变化时在此失败，而不是静默产出坏数据。
    if len(data) != 14 or academic != 117 or professional != 67 or master_only != 31:
        raise SystemExit(
            f"校验失败：门类 {len(data)}（应为14），一级学科 {academic}（应为117），"
            f"专业学位类别 {professional}（应为67），仅硕士 {master_only}（应为31）"
        )

    output = {
        "meta": {
            "source": "研究生教育学科专业目录（2022年）",
            "issuer": "国务院学位委员会 教育部",
            "edition": 2022,
            "generatedAt": datetime.now(timezone(timedelta(hours=8))).isoformat(),
            "academicCount": academic,
            "professionalCount": professional,
        },
        "categories": data,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, separators=(",", ":"))
    print(f"已生成 {OUT}：14 门类，{academic} 个一级学科，{professional} 个专业学位类别")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:  # 网络失败等给出可读提示
        print(f"抓取失败：{exc}", file=sys.stderr)
        sys.exit(1)

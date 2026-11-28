#!/usr/bin/env python3
"""Export Project TOWER's scene-based localization workbook to Godot CSV."""

from __future__ import annotations

import argparse
import csv
import io
import re
from pathlib import Path
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree as ET
from zipfile import BadZipFile, ZipFile

from export_settings import MAIN_NS, ROOT, SettingsError, require, rows_after_header, workbook_rows


CSV_HEADER = ["keys", "zh_CN", "en_US", "_category", "_context", "_status"]
WORKBOOK_HEADER = ["keys", "出现位置", "zh_CN", "en_US", "_category", "_context", "_status", "导出顺序"]
GUIDE_SHEET = "导入说明"
CATEGORIES = {"menu", "hud", "transition", "narrative", "equipment", "inventory", "codex", "settings", "result", "input"}
STATUSES = {"placeholder", "draft", "approved"}
VARIABLE = re.compile(r"\{([a-z_][a-z0-9_]*)\}")


def variables(text: str, location: str) -> set[str]:
    rest = VARIABLE.sub("", text)
    require("{" not in rest and "}" not in rest, location, "存在无效或未闭合的占位符")
    return set(VARIABLE.findall(text))


def export_csv(workbook: Path, candidate: bool) -> tuple[str, int]:
    with ZipFile(workbook) as archive:
        book = ET.fromstring(archive.read("xl/workbook.xml"))
        names = tuple(sheet.attrib["name"] for sheet in book.iter(MAIN_NS + "sheet")
                      if sheet.attrib["name"] != GUIDE_SHEET)
        require(bool(names), workbook.name, "未找到文本工作表")
        sheets = workbook_rows(archive, names)
    by_order: dict[int, list[str]] = {}
    appended: list[list[str]] = []
    locations: dict[str, str] = {}
    for name, sheet in sheets.items():
        for location, values in rows_after_header(sheet, WORKBOOK_HEADER, name):
            key, placement, zh, en, category, context, status, order = values
            require(all(isinstance(value, str) and value.strip() for value in values[:7]),
                    location, "String ID、出现位置、双语正文、类别、上下文和状态均须填写文本")
            where = f"{location} · {key}"
            require(re.fullmatch(r"[A-Z][A-Z0-9_]*", key) is not None, where, "String ID 格式无效")
            require(key not in locations, where, f"String ID 重复，首次出现于 {locations.get(key, '')}")
            require(category in CATEGORIES, where, f"类别无效 {category!r}")
            require(status in STATUSES, where, f"状态无效 {status!r}")
            require(not candidate or status != "placeholder", where, "候选构建不接受 placeholder")
            require(variables(zh, where) == variables(en, where), where, "两种语言的占位符不一致")
            locations[key] = location
            record = [key, zh, en, category, context, status]
            if order in (None, ""):
                appended.append(record)
            else:
                require(type(order) is int and order > 0, where, "导出顺序应为正整数或留空")
                require(order not in by_order, where, f"导出顺序重复 {order}")
                by_order[order] = record

    require(bool(locations), workbook.name, "未找到文本记录")
    output = io.StringIO(newline="")
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(CSV_HEADER)
    writer.writerows(by_order[index] for index in sorted(by_order))
    writer.writerows(appended)
    return output.getvalue(), len(locations)


def write_atomic(path: Path, content: bytes) -> None:
    temporary = None
    try:
        with NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as handle:
            temporary = Path(handle.name)
            handle.write(content)
        temporary.chmod(path.stat().st_mode & 0o777 if path.exists() else 0o644)
        temporary.replace(path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path, help="按场景分表的本地化工作簿")
    parser.add_argument("--output", type=Path, default=ROOT / "localization/game.csv",
                        help="输出 CSV 路径，默认写入项目的 localization/game.csv")
    parser.add_argument("--check", action="store_true", help="只检查工作簿与现有 CSV 是否一致")
    parser.add_argument("--candidate", action="store_true", help="候选构建检查，拒绝开发占位文本")
    args = parser.parse_args()
    try:
        require(args.output.suffix.lower() == ".csv", str(args.output), "输出路径须使用 .csv 扩展名")
        content, count = export_csv(args.workbook, args.candidate)
        payload = content.encode("utf-8")
        matches = args.output.is_file() and args.output.read_bytes() == payload
        if args.check:
            require(matches, str(args.output), "工作簿与现有 CSV 不一致")
        elif not matches:
            write_atomic(args.output, payload)
        print(f"{'已核对' if args.check else '已导出'} {count} 个 String ID")
    except (SettingsError, OSError, BadZipFile, ET.ParseError, KeyError) as exc:
        parser.exit(1, f"{exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

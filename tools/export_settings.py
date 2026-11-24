#!/usr/bin/env python3
"""Validate the Project TOWER settings workbook and export its Godot resources."""

from __future__ import annotations

import argparse
import csv
import json
import math
import posixpath
import re
from pathlib import Path
from typing import Callable
from xml.etree import ElementTree as ET
from zipfile import BadZipFile, ZipFile


ROOT = Path(__file__).resolve().parents[1]
MAIN_NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
DOCUMENT_RELS_NS = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
SETTINGS_HEADER = ["分组", "实体 ID", "字段", "值", "单位"]
FLOOR_HEADER = ["层", "掩体数", "中心开阔", "提示 ID", "附注 ID", "第 1 波", "第 2 波", "清场掉落"]
STACKABLE = {"MUSHROOM", "WATER", "POTION"}
STARTERS = {"START_SWORD", "START_STAFF"}
MANUSCRIPTS = {
    "LORE_KIT", "LORE_ORDER", "LORE_F1", "LORE_F2", "LORE_PRAYER", "LORE_F3",
    "LORE_F4", "LORE_RESEARCH", "LORE_F5", "LORE_CAMP", "LORE_ROSTER",
    "LORE_RETREAT", "LORE_TRIAL", "LORE_LAST_REPORT",
}
FLOOR_HEX = [(64, 360), (256, 64), (1024, 64), (1216, 360), (1024, 656), (256, 656)]
ENEMY_BEHAVIORS = {
    "slime": "slime",
    "goblin": "goblin",
    "skeleton": "skeleton",
    "archer": "archer",
    "elite": "skeleton",
    "ghost": "ghost",
    "corrupted_slime": "slime",
    "corrupted_goblin": "goblin",
    "corrupted_skeleton": "skeleton",
    "corrupted_archer": "archer",
    "lord": "lord",
}
FLOOR_ENEMY_RULES = [
    ("slime", "slime"),
    ("slime goblin", "slime goblin"),
    ("slime goblin skeleton", "skeleton"),
    ("slime goblin skeleton archer", "slime goblin skeleton archer"),
    ("elite", "elite"),
    ("ghost corrupted_slime", "ghost corrupted_slime"),
    ("ghost corrupted_slime corrupted_goblin", "corrupted_goblin"),
    ("ghost corrupted_slime corrupted_goblin corrupted_skeleton", "corrupted_skeleton"),
    ("ghost corrupted_slime corrupted_goblin corrupted_skeleton corrupted_archer", "corrupted_archer"),
    ("lord", "lord"),
]


class SettingsError(ValueError):
    pass


def require(condition: bool, context: str, message: str) -> None:
    if not condition:
        raise SettingsError(f"{context} · {message}")


def number(value, context: str) -> float:
    require(type(value) in (int, float) and -1e15 <= value <= 1e15, context, "需要有限范围内的数值")
    return float(value)


def positive(value, context: str) -> float:
    result = number(value, context)
    require(result > 0.0, context, "需要大于 0")
    return result


def nonnegative(value, context: str) -> float:
    result = number(value, context)
    require(result >= 0.0, context, "需要大于或等于 0")
    return result


def fraction(value, context: str) -> float:
    result = nonnegative(value, context)
    require(result <= 1.0, context, "比例应在 0–1 之间")
    return result


def whole(value, context: str) -> int:
    result = nonnegative(value, context)
    require(result.is_integer(), context, "需要整数")
    return int(result)


def boolean(value, context: str) -> bool:
    require(type(value) in (bool, int, float) and value in (False, True), context, "需要 TRUE、FALSE、0 或 1")
    return bool(value)


def identifier(value, context: str) -> str:
    require(isinstance(value, str) and bool(re.fullmatch(r"[a-zA-Z_][a-zA-Z_0-9-]*", value)),
            context, "需要稳定 ID")
    return value


def string(value, context: str) -> str:
    require(isinstance(value, str) and bool(value.strip()), context, "需要文本")
    return value


def json_array(value, context: str) -> list:
    require(isinstance(value, str), context, "需要 JSON 数组文本")
    try:
        result = json.loads(value)
    except ValueError as exc:
        raise SettingsError(f"{context} · JSON 数组格式无效") from exc
    require(isinstance(result, list), context, "需要 JSON 数组")
    return result


def option(*choices: str) -> Callable:
    def parse(value, context: str):
        require(value in choices, context, f"允许的值为 {', '.join(choices)}")
        return value

    return parse


def fields(keys: str, parser: Callable = positive) -> dict:
    return dict.fromkeys(keys.split(), parser)


ENEMY_BASE = fields("behavior", identifier) | fields("hp speed damage cooldown")
ENEMY_FIELDS = {
    "slime": fields("creep_speed coil_time contact_range lunge_speed lunge_time recover lunge_cooldown"),
    "goblin": fields("strike_trigger strike_reach strike_angle telegraph"),
    "skeleton": fields("telegraph reach shot_speed band_min band_max") | fields("shots", whole),
    "archer": fields("draw shot_speed band_min band_max backpedal reach melee_range melee_reach "
                     "melee_windup melee_damage melee_cooldown melee_arc") | fields("burst_shots", whole),
    "ghost": fields("strike_trigger strike_reach telegraph recover"),
    "lord": fields("strike_trigger strike_reach strike_angle telegraph cast_telegraph reach "
                   "spread shot_speed zone_radius zone_delay zone_damage zone_reach") |
            fields("shots", whole) | fields("phase_threshold phase_delay_factor", fraction),
}
ENEMY_EXTRA = {
    "elite": fields("spread"),
    "corrupted_slime": fields("trail_radius trail_time trail_damage"),
    "corrupted_goblin": fields("rush_trigger rush_telegraph rush_speed rush_time rush_recover"),
    "corrupted_skeleton": fields("zone_radius zone_delay zone_damage zone_reach"),
    "corrupted_archer": fields("burst_draw"),
}
CORRUPTION_FIELDS = fields("increase") | fields("limit", whole)
WEAPON_FIELDS = {
    "range_type": option("melee", "ranged"),
    "damage_type": option("physical", "magic"),
    **fields("interval minimum"),
}
ITEM_FIELDS = {
    "slot": option("weapon", "gloves", "accessory", "armor", "shoes"),
    "type": option("sword_damage", "magic_damage", "sword_cooldown", "magic_cooldown",
                   "critical", "lifesteal", "health", "speed"),
    "value": positive,
}
FIXED_GROUPS = {
    "ENEMIES": {
        kind: ENEMY_BASE | ENEMY_FIELDS[behavior] | ENEMY_EXTRA.get(kind, {}) |
        ({"corrupted": boolean} if kind.startswith("corrupted_") else {})
        for kind, behavior in ENEMY_BEHAVIORS.items()
    },
    "WAVE_TIMING": {"-": fields("first_wave_delay between_waves_delay spawn_warning spawn_stagger")},
    "WORLD": {
        "-": fields("ID", string) | fields("POT_COUNT EARLY_PLATE_COUNT LATE_PLATE_COUNT", whole) |
        fields("POT_RADIUS PLATE_RADIUS PLATE_WARNING PLATE_RESET ARROW_DAMAGE ARROW_SPEED "
               "ARROW_RANGE ARROW_SOURCE_DISTANCE") | fields("POT_DROPS", json_array),
    },
    "CORRUPTION": dict.fromkeys(["physical", "magic", "max_hp", "speed", "critical", "interval"],
                               CORRUPTION_FIELDS),
    "PLAYER_BASE": {"-": fields("physical magic max_hp speed physical_interval_scale magic_interval_scale") |
                        fields("lifesteal", nonnegative) | fields("critical", fraction)},
    "PLAYER_LIMITS": {"-": fields("MAX_BEADS", whole) | fields("CRITICAL_MAX", fraction) |
                          fields("CRITICAL_MULTIPLIER")},
    "LOOT": {"-": {"DROP_CUTOFFS": json_array, "POTION_HEAL": positive}},
    "RECIPE": {"-": fields("MUSHROOM WATER", whole)},
}
DYNAMIC_GROUPS = {"WEAPONS": WEAPON_FIELDS, "ITEMS": ITEM_FIELDS}


def workbook_rows(archive: ZipFile, names: tuple[str, ...]) -> dict:
    book = ET.fromstring(archive.read("xl/workbook.xml"))
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {
        relationship.attrib["Id"]: relationship.attrib["Target"]
        for relationship in relationships
        if relationship.get("TargetMode") != "External"
    }
    paths = {
        sheet.attrib["name"]: targets.get(sheet.get(DOCUMENT_RELS_NS + "id", ""), "")
        for sheet in book.iter(MAIN_NS + "sheet")
    }
    shared = []
    if "xl/sharedStrings.xml" in archive.namelist():
        shared_node = ET.fromstring(archive.read("xl/sharedStrings.xml"))
        shared = [read_rich_text(item) for item in shared_node.findall(MAIN_NS + "si")]
    output = {}
    for name in names:
        target = paths.get(name)
        require(bool(target), name, "缺少工作表")
        path = target.lstrip("/") if target.startswith("/") else posixpath.normpath(posixpath.join("xl", target))
        sheet = ET.fromstring(archive.read(path))
        output[name] = read_rows(sheet, shared, name)
    return output


def read_rich_text(element: ET.Element) -> str:
    return "".join(node.text or "" for node in element.iter(MAIN_NS + "t"))


def read_rows(sheet: ET.Element, shared: list[str], name: str) -> list[tuple[int, list]]:
    rows = []
    for row in sheet.iter(MAIN_NS + "row"):
        index = int(row.get("r", len(rows) + 1))
        values = []
        for cell in row.findall(MAIN_NS + "c"):
            ref = cell.get("r", "")
            column = len(values)
            if ref:
                match = re.fullmatch(r"([A-Z]+)[1-9][0-9]*", ref)
                require(match is not None, f"{name} {ref}", "单元格地址无效")
                column = 0
                for letter in match.group(1):
                    column = column * 26 + ord(letter) - ord("A") + 1
                column -= 1
            require(0 <= column < 16384, f"{name} {ref}", "单元格列无效")
            values.extend([None] * (column + 1 - len(values)))
            values[column] = read_cell(cell, shared, f"{name} {ref or index}")
        while values and values[-1] in (None, ""):
            values.pop()
        if values:
            rows.append((index, values))
    return rows


def read_cell(cell: ET.Element, shared: list[str], context: str):
    require(cell.find(MAIN_NS + "f") is None, context, "参数与楼层数据必须使用固定值")
    kind = cell.get("t", "n")
    if kind == "inlineStr":
        return read_rich_text(cell)
    value = cell.findtext(MAIN_NS + "v")
    if value is None:
        return None
    if kind == "s":
        require(value.isdigit() and int(value) < len(shared), context, "共享字符串索引无效")
        return shared[int(value)]
    if kind == "str":
        return value
    if kind == "b":
        require(value in ("0", "1"), context, "布尔值无效")
        return value == "1"
    if kind == "n":
        try:
            return int(value) if re.fullmatch(r"-?[0-9]+", value) else float(value)
        except ValueError as exc:
            raise SettingsError(f"{context} · 数字格式无效") from exc
    raise SettingsError(f"{context} · 不支持的单元格类型 {kind}")


def rows_after_header(rows: list, header: list[str], name: str):
    require(bool(rows) and rows[0] == (1, header), name, f"首行应为 {', '.join(header)}")
    for index, values in rows[1:]:
        context = f"{name} 第 {index} 行"
        require(len(values) <= len(header), context, "超出了表头列范围")
        yield context, values + [None] * (len(header) - len(values))


def parse_settings(rows: list) -> tuple[dict, dict]:
    settings: dict = {}
    source: dict = {}
    for context, (group, entity, field, value, _unit) in rows_after_header(rows, SETTINGS_HEADER, "参数"):
        require(isinstance(group, str) and (group in FIXED_GROUPS or group in DYNAMIC_GROUPS),
                context, f"分组无效 {group!r}")
        require(isinstance(entity, str) and isinstance(field, str), context, "实体 ID 与字段不能为空")
        if group in FIXED_GROUPS:
            schema = FIXED_GROUPS[group].get(entity)
            require(schema is not None, context, f"{group} 的实体 ID 无效 {entity!r}")
        else:
            identifier(entity, context)
            schema = DYNAMIC_GROUPS[group]
        path = group, entity, field
        require(field in schema, context, f"{group}/{entity} 的字段无效 {field!r}")
        require(path not in source, context, f"字段重复，首次出现在 {source.get(path, '')}")
        source[path] = context
        settings.setdefault(group, {}).setdefault(entity, {})[field] = schema[field](value, context)
    for group, entities in FIXED_GROUPS.items():
        for entity, schema in entities.items():
            require_fields(settings, group, entity, schema, source)
    for group, schema in DYNAMIC_GROUPS.items():
        require(bool(settings.get(group)), "参数", f"缺少分组 {group}")
        for entity in settings[group]:
            require_fields(settings, group, entity, schema, source)
    return settings, source


def require_fields(settings: dict, group: str, entity: str, schema: dict, source: dict) -> None:
    present = settings.get(group, {}).get(entity, {})
    missing = set(schema) - set(present)
    context = source.get((group, entity, next(iter(present), "")), "参数")
    require(not missing, context, f"{group}/{entity} 缺少字段 {', '.join(sorted(missing))}")


def load_localization() -> dict[str, tuple[str, str]]:
    with (ROOT / "localization/game.csv").open(encoding="utf-8-sig", newline="") as file:
        return {row["keys"]: (row["zh_CN"], row["en_US"]) for row in csv.DictReader(file)}


def require_translation(key: str, texts: dict, context: str) -> tuple[str, str]:
    value = texts.get(key)
    require(value is not None and all(value), context, f"缺少完整双语文本 {key}")
    return value


def validate_settings(settings: dict, source: dict, texts: dict) -> set[str]:
    for kind, config in settings["ENEMIES"].items():
        context = source["ENEMIES", kind, "behavior"]
        require(config["behavior"] == ENEMY_BEHAVIORS[kind], context, "敌人行为要对应现有场景")
        if kind.startswith("corrupted_"):
            require(config["corrupted"], source["ENEMIES", kind, "corrupted"], "腐蚀变体需要标记")
        for field in ("shots", "burst_shots"):
            if field in config:
                require(1 <= config[field] <= 8, source["ENEMIES", kind, field], "发数需在 1–8 之间")
        if kind in {"archer", "corrupted_archer"}:
            valid_burst = config["burst_shots"] == 1 if kind == "archer" else config["burst_shots"] >= 2
            require(valid_burst, source["ENEMIES", kind, "burst_shots"], "常规弓手单发，腐蚀弓手分段连射")
        if kind == "lord":
            require(config["phase_delay_factor"] > 0.0, source["ENEMIES", kind, "phase_delay_factor"],
                    "阶段前摇倍率必须大于 0")
        if "band_min" in config:
            require(config["band_min"] < config["band_max"] <= config["reach"],
                    source["ENEMIES", kind, "band_max"], "射程需覆盖交战距离带")
        if "strike_trigger" in config:
            require(config["strike_trigger"] <= config["strike_reach"],
                    source["ENEMIES", kind, "strike_trigger"], "近战触发距离不可超出命中范围")
        if "melee_range" in config:
            require(config["melee_range"] <= config["melee_reach"],
                    source["ENEMIES", kind, "melee_range"], "近战触发距离不可超出命中范围")
        prefix = f"ENEMY_{kind.upper()}"
        require_translation(prefix + "_NAME", texts, context)
        description = require_translation(prefix + "_DESC", texts, context)
        placeholders = [set(re.findall(r"\{([a-zA-Z_0-9]+)\}", text)) for text in description]
        require(placeholders[0] == placeholders[1], context, f"{prefix}_DESC 的双语变量必须一致")
        require(placeholders[0] <= set(config), context, f"{prefix}_DESC 使用了未知敌人参数")

    weapon_ids = set(STARTERS)
    for entity, item in settings["ITEMS"].items():
        context = source["ITEMS", entity, "slot"]
        require(re.fullmatch(r"U[0-9]+", entity) is not None, context, "装备 ID 应使用 U 加数字")
        if item["slot"] == "weapon":
            weapon_ids.add(entity)
        if item["type"] in ("sword_cooldown", "magic_cooldown", "critical"):
            require(item["value"] <= 1.0, source["ITEMS", entity, "value"], "比例不得超过 1")
        for suffix in ("NAME", "DESC"):
            require_translation(f"ITEM_{entity}_{suffix}", texts, context)
    require(set(settings["WEAPONS"]) == weapon_ids, "参数", "武器配置要覆盖两件初始武器和所有武器类装备")
    for entity, weapon in settings["WEAPONS"].items():
        require(weapon["minimum"] <= weapon["interval"],
                source["WEAPONS", entity, "minimum"], "间隔下限不得大于基础间隔")

    world = settings["WORLD"]["-"]
    for field in ("POT_COUNT", "EARLY_PLATE_COUNT", "LATE_PLATE_COUNT"):
        require(world[field] <= 8, source["WORLD", "-", field], "场地机关数量范围为 0–8")
    require(bool(world["POT_DROPS"]) and all(isinstance(item, str) and (not item or item in STACKABLE)
                                           for item in world["POT_DROPS"]),
            source["WORLD", "-", "POT_DROPS"], "罐子掉落需要有效道具 ID 或空字符串")
    require(world["ARROW_RANGE"] > world["ARROW_SOURCE_DISTANCE"],
            source["WORLD", "-", "ARROW_RANGE"], "箭程必须越过触发板")

    limits = settings["PLAYER_LIMITS"]["-"]
    require(limits["MAX_BEADS"] == 9, source["PLAYER_LIMITS", "-", "MAX_BEADS"], "前九层每层凝一颗")
    for entity, corruption in settings["CORRUPTION"].items():
        require(1 <= corruption["limit"] <= limits["MAX_BEADS"], source["CORRUPTION", entity, "limit"],
                "魔化上限必须在 1–9 级之间")
    interval = settings["CORRUPTION"]["interval"]
    require(interval["increase"] * interval["limit"] < 1.0, source["CORRUPTION", "interval", "increase"],
            "满级魔化必须保留正数攻击间隔倍率")
    cutoff_context = source["LOOT", "-", "DROP_CUTOFFS"]
    cutoffs = [whole(value, cutoff_context) for value in settings["LOOT"]["-"]["DROP_CUTOFFS"]]
    require(len(cutoffs) == 3 and 0 <= cutoffs[0] < cutoffs[1] < cutoffs[2] <= 100,
            cutoff_context, "需要三个递增的百分比阈值（0–100）")
    settings["LOOT"]["-"]["DROP_CUTOFFS"] = cutoffs
    for field, quantity in settings["RECIPE"]["-"].items():
        require(quantity > 0, source["RECIPE", "-", field], "配方使用正数数量")
    return STACKABLE | STARTERS | MANUSCRIPTS | set(settings["ITEMS"])


def inside_floor(x: float, y: float, margin: float) -> bool:
    edges = zip(FLOOR_HEX, FLOOR_HEX[1:] + FLOOR_HEX[:1])
    for (start_x, start_y), (end_x, end_y) in edges:
        dx, dy = end_x - start_x, end_y - start_y
        if dx * (y - start_y) - dy * (x - start_x) < margin * math.hypot(dx, dy):
            return False
    return True


def parse_floors(rows: list, item_ids: set[str], texts: dict) -> dict:
    floors = {}
    for context, values in rows_after_header(rows, FLOOR_HEADER, "楼层"):
        index, obstacle_count, center_open, tip, note, first_wave, second_wave, pickup_cell = values
        index = whole(index, context)
        require(1 <= index <= 10 and index not in floors, context, "需要唯一楼层号 1–10")
        obstacles = whole(obstacle_count, context)
        center_open = boolean(center_open, context)
        require(obstacles <= (4 if center_open else 7), context, "掩体数量超出当前布局容量")
        tip = identifier(tip, context)
        require_translation(tip, texts, context)
        if note:
            note = identifier(note, context)
            require_translation(note, texts, context)
        waves = [parse_wave(first_wave, context)]
        if second_wave not in (None, ""):
            waves.append(parse_wave(second_wave, context))
        allowed, required = (set(group.split()) for group in FLOOR_ENEMY_RULES[index - 1])
        kinds = set().union(*waves)
        require(kinds <= allowed, context, "本层包含计划外敌人")
        require(required <= kinds, context, "本层缺少计划中的敌人")
        require(index != 10 or waves == [["lord"]], context, "塔顶只有一名魔化领主")
        pickups = parse_pickups(pickup_cell, item_ids, texts, context)
        floors[index] = (obstacles, center_open, tip, note, waves, pickups)
    require(set(floors) == set(range(1, 11)), "楼层", "需要包含 F1 至 F10")
    return floors


def parse_wave(value, context: str) -> list[str]:
    kinds = [kind.strip() for kind in string(value, context).split(",")]
    require(1 <= len(kinds) <= 6 and all(kind in ENEMY_BEHAVIORS for kind in kinds),
            context, "每波需包含 1–6 个有效敌人 ID")
    return kinds


def parse_pickups(value, item_ids: set[str], texts: dict, context: str) -> list:
    pickups = []
    occupied = set()
    for pickup in json_array(value, context):
        require(isinstance(pickup, list) and len(pickup) == 3, context, "掉落格式为 [x, y, 物品 ID]")
        x, y = (number(coordinate, context) for coordinate in pickup[:2])
        entity = identifier(pickup[2], context)
        require(entity in item_ids, context, f"未知清场掉落物品 {entity}")
        require(inside_floor(x, y, 25.0) and (x, y) not in occupied,
                context, "清场掉落坐标必须在可达六边形内且不能重叠")
        occupied.add((x, y))
        if entity in MANUSCRIPTS:
            for suffix in ("TITLE", "DESC", "BODY"):
                require_translation(f"{entity}_{suffix}", texts, context)
        pickups.append((x, y, entity))
    return pickups


def gd_value(value) -> str:
    if isinstance(value, dict):
        return "{" + ", ".join(f"{gd_value(key)}: {gd_value(item)}" for key, item in value.items()) + "}"
    if isinstance(value, list):
        return "[" + ", ".join(map(gd_value, value)) + "]"
    return json.dumps(value, ensure_ascii=False, allow_nan=False)


def render_settings(settings: dict) -> str:
    lines = [
        "extends RefCounted",
        "",
        "# Generated by tools/export_settings.py from the complete-edition settings workbook.",
        "# Distances use world pixels, durations use seconds, and angles use radians.",
    ]
    for group, entities in FIXED_GROUPS.items():
        entries = settings[group]
        if set(entities) == {"-"}:
            lines += ["", f"const {group} := {{"]
            lines.extend(f'\t"{field}": {gd_value(entries["-"][field])},' for field in entities["-"])
        else:
            lines += ["", f"const {group} := {{"]
            for entity, schema in entities.items():
                lines.append(f'\t"{entity}": {{')
                lines.extend(f'\t\t"{field}": {gd_value(entries[entity][field])},' for field in schema)
                lines.append("\t},")
        lines.append("}")
    weapons = settings["WEAPONS"]
    lines += ["", "const WEAPONS := {"]
    for entity in sorted(weapons):
        data = {field: weapons[entity][field] for field in WEAPON_FIELDS}
        lines.append(f'\t"{entity}": {gd_value(data)},')
    lines += ["}", "", "const ITEMS := ["]
    for entity, item in sorted(settings["ITEMS"].items()):
        entry = {"id": entity, **{field: item[field] for field in ITEM_FIELDS}}
        lines.append(f"\t{gd_value(entry)},")
    return "\n".join(lines + ["]", ""])


def render_floor(floor: tuple) -> str:
    obstacles, center_open, tip, note, waves, pickups = floor
    lines = [
        '[gd_resource type="Resource" script_class="FloorDefinition" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://data/floor_definition.gd" id="1"]',
        "",
        "[resource]",
        'script = ExtResource("1")',
        f"tip_key = {gd_value(tip)}",
    ]
    if note:
        lines.append(f"entry_note_key = {gd_value(note)}")
    wave_arrays = ", ".join("PackedStringArray(" + ", ".join(map(gd_value, wave)) + ")" for wave in waves)
    lines.append(f"waves = Array[PackedStringArray]([{wave_arrays}])")
    lines.append(f"obstacle_count = {obstacles}")
    if center_open:
        lines.append("keep_center_open = true")
    if pickups:
        mapping = ", ".join(f"Vector2({gd_value(x)}, {gd_value(y)}): {gd_value(entity)}"
                            for x, y, entity in pickups)
        lines.append("clear_pickups = Dictionary[Vector2, String]({" + mapping + "})")
    return "\n".join(lines + [""])


def build_outputs(settings: dict, floors: dict) -> dict[Path, str]:
    files = {ROOT / "data/edition_settings.gd": render_settings(settings)}
    files.update({ROOT / f"data/floors/floor_{index:02d}.tres": render_floor(floors[index])
                  for index in sorted(floors)})
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path, help="包含「参数」和「楼层」的数据工作簿（.xlsx）")
    parser.add_argument("--check", action="store_true", help="核对当前游戏资源与表格一致")
    args = parser.parse_args()
    try:
        with ZipFile(args.workbook) as archive:
            sheets = workbook_rows(archive, ("参数", "楼层"))
        texts = load_localization()
        settings, source = parse_settings(sheets["参数"])
        item_ids = validate_settings(settings, source, texts)
        floors = parse_floors(sheets["楼层"], item_ids, texts)
        files = build_outputs(settings, floors)
        if args.check:
            stale = [str(path.relative_to(ROOT)) for path, content in files.items()
                     if not path.exists() or path.read_text(encoding="utf-8") != content]
            require(not stale, "设定表与打包资源不同步", ", ".join(stale))
            print(f"已核对 {len(files)} 个资源")
        else:
            for path, content in files.items():
                path.write_text(content, encoding="utf-8", newline="\n")
            print(f"已导出 {len(files)} 个资源")
    except (SettingsError, OSError, BadZipFile, ET.ParseError, KeyError) as exc:
        parser.exit(1, f"{exc}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

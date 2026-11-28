extends Control

signal item_requested(operation: String, id: String)

const GameData = preload("res://data/game_data.gd")
const PlayerStats = preload("res://data/player_stats.gd")
const UpgradeArt = preload("res://data/upgrade_art.gd")
const EditionArt = preload("res://data/edition_art.gd")
const TABS := ["UI_BAG_TITLE", "UI_CORRUPTION_TITLE", "UI_CRAFT_TITLE", "UI_CODEX_TITLE"]
const TAB_ICONS := ["ui_inventory", "ui_blood", "ui_craft", "ui_codex"]
const CATEGORIES := ["SUPPLIES", "EQUIPMENT", "MANUSCRIPTS", "ENEMIES"]
const LIST_X := 186.0
const LIST_WIDTH := 412.0
const DETAIL_X := 675.0
const DETAIL_WIDTH := 419.0
const DETAIL_END := 485.0
const COMPARED_STATS := ["physical", "magic", "max_hp", "speed", "critical", "lifesteal"]

enum Page { BAG, CORRUPTION, CRAFT, CODEX }

var ui: CanvasLayer
var loc: Node
var inventory: RunInventory
var codex: RunCodex
var hero: Node2D
var standalone := false
var magic_allowed := true
var page := Page.BAG
var active_family := "SUPPLIES"
var selected := ""
var operation := ""
var tab_buttons: Array[Button] = []
var family_buttons: Array[Button] = []
var title: Label
var spread: TextureRect
var comparison: GridContainer
var recipe_materials: VBoxContainer
var entries: ItemList
var column_rule: ColorRect
var picture: TextureRect
var detail_title: Label
var detail: RichTextLabel
var annotation: Label
var action: Button
var quick: Button
var back: Button

func setup(interface: CanvasLayer, service: Node) -> void:
	ui = interface
	loc = service
	ui._dimmer(self, 0.80)
	ui._panel(self, Rect2(146, 53, 988, 613))
	spread = TextureRect.new()
	spread.name = "LeatherBinding"
	spread.position = Vector2(141, 48)
	spread.size = Vector2(998, 623)
	spread.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spread.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spread.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spread)
	title = ui._label(self, Vector2(LIST_X, 80), Vector2(413, 42), 26, ui.INK)
	_build_tabs()
	for x in [LIST_X, DETAIL_X]:
		ui._color(self, Rect2(x, 132, 411, 1), ui.RULE)
	column_rule = ui._color(self, Rect2(639, 152, 1, 410), ui.RULE)
	entries = ItemList.new()
	entries.name = "Items"
	entries.position = Vector2(LIST_X, 152)
	entries.size = Vector2(LIST_WIDTH, 410)
	entries.fixed_icon_size = Vector2i(28, 28)
	entries.add_theme_constant_override("v_separation", 10)
	entries.add_theme_color_override("font_color", ui.INK)
	add_child(entries)
	entries.item_selected.connect(func(index: int):
		selected = str(entries.get_item_metadata(index))
		ui.ui_sound_requested.emit("ui_focus")
		_refresh_selection())
	recipe_materials = VBoxContainer.new()
	recipe_materials.name = "RecipeMaterials"
	recipe_materials.position = Vector2(LIST_X, 152)
	recipe_materials.custom_minimum_size.x = LIST_WIDTH
	recipe_materials.add_theme_constant_override("separation", 12)
	add_child(recipe_materials)
	picture = TextureRect.new()
	picture.name = "Illustration"
	picture.position = Vector2(DETAIL_X, 152)
	picture.size = Vector2(91, 91)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	detail_title = ui._label(self, Vector2(DETAIL_X, 152), Vector2(DETAIL_WIDTH, 65), 25, ui.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	detail = RichTextLabel.new()
	detail.name = "Details"
	detail.position = Vector2(DETAIL_X, 258)
	detail.size = Vector2(DETAIL_WIDTH, 209)
	detail.add_theme_color_override("default_color", ui.INK)
	detail.add_theme_constant_override("line_separation", 7)
	detail.selection_enabled = true
	add_child(detail)
	comparison = GridContainer.new()
	comparison.name = "StatComparison"
	comparison.columns = 3
	comparison.position = Vector2(DETAIL_X, 318)
	comparison.add_theme_constant_override("h_separation", 7)
	comparison.add_theme_constant_override("v_separation", 0)
	comparison.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(comparison)
	annotation = ui._label(self, Vector2(DETAIL_X, 474), Vector2(DETAIL_WIDTH, 43), 15, ui.MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	action = ui._button(self, "ItemAction", Rect2(DETAIL_X, 522, DETAIL_WIDTH, 44), true)
	action.pressed.connect(func(): item_requested.emit(operation, selected))
	quick = ui._button(self, "QuickSlot", Rect2(DETAIL_X, 583, DETAIL_WIDTH, 43))
	quick.pressed.connect(func(): item_requested.emit("quick", selected))
	back = ui._button(self, "Back", Rect2(LIST_X, 583, 162, 43))
	back.pressed.connect(func(): ui.close_requested.emit())

func _build_tabs() -> void:
	var tabs := ButtonGroup.new()
	for index in range(TABS.size()):
		var x := LIST_X + float(index % 2) * 210.0 if index < 2 else DETAIL_X + float(index % 2) * 210.0
		var button: Button = ui._button(self, "Tab%d" % index, Rect2(x, 80, 201, 44), false, "book_page")
		button.theme_type_variation = &"TabButton"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ui._set_command_icon(button, TAB_ICONS[index], 19)
		button.toggle_mode = true
		button.button_group = tabs
		button.pressed.connect(_switch_page.bind(index))
		tab_buttons.append(button)
	var families := ButtonGroup.new()
	for index in range(CATEGORIES.size()):
		var button: Button = ui._button(self, "Family%d" % index, Rect2(LIST_X + 104 * index, 146, 101, 34), false, "book_page")
		button.theme_type_variation = &"TabButton"
		button.add_theme_font_size_override("font_size", 14)
		button.toggle_mode = true
		button.button_group = families
		button.pressed.connect(_switch_family.bind(CATEGORIES[index]))
		family_buttons.append(button)

func show_inventory(model: RunInventory, player: Node2D, progress: RunCodex) -> void:
	if inventory != model or standalone:
		page = Page.BAG
		selected = ""
	inventory = model
	hero = player
	codex = progress
	standalone = false
	refresh()

func show_codex(progress: RunCodex) -> void:
	inventory = null
	hero = null
	codex = progress
	standalone = true
	_switch_page(Page.CODEX)

func _switch_page(index: int) -> void:
	page = index as Page
	selected = ""
	refresh()

func _switch_family(family: String) -> void:
	active_family = family
	selected = ""
	refresh()

func refresh() -> void:
	if inventory == null and not standalone:
		return
	back.text = loc.text("UI_BACK")
	spread.texture = UpgradeArt.prop("codex_spread" if page == Page.CODEX else "book_spread")
	title.visible = standalone
	if standalone:
		title.text = loc.text("UI_CODEX_TITLE")
	for index in range(TABS.size()):
		var button := tab_buttons[index]
		button.visible = not standalone
		button.text = loc.text(TABS[index])
		button.set_pressed_no_signal(index == page)
	for index in range(CATEGORIES.size()):
		var button := family_buttons[index]
		var family: String = CATEGORIES[index]
		button.visible = page == Page.CODEX
		button.text = loc.text("UI_CODEX_%s" % family)
		button.set_pressed_no_signal(active_family == family)
	var top := _content_top()
	entries.position.y = top
	entries.size.y = 562.0 - top
	entries.visible = page != Page.CRAFT
	recipe_materials.visible = page == Page.CRAFT
	column_rule.visible = spread.texture == null
	column_rule.position.y = top
	column_rule.size.y = entries.size.y
	entries.clear()
	match page:
		Page.BAG: _fill_bag()
		Page.CORRUPTION: _fill_corruption()
		Page.CRAFT: selected = "POTION"
		Page.CODEX: _fill_codex()
	if page != Page.CRAFT and not entries.is_anything_selected():
		selected = ""
		if entries.item_count > 0:
			entries.select(0)
			selected = str(entries.get_item_metadata(0))
	entries.ensure_current_is_visible()
	_refresh_selection()

func _fill_bag() -> void:
	for id in GameData.STACKABLE:
		if inventory.count(id) > 0 or (id == "POTION" and inventory.potion_on_quick_slot):
			_add_row(id, "%s  ×%d" % [_item_name(id), inventory.count(id)], id)
	for id in inventory.owned:
		var item := _item_name(id)
		if id in inventory.equipped.values():
			item = loc.text("UI_ITEM_EQUIPPED", {"item": item})
		elif GameData.is_book(id) and not _has_read(id):
			item = loc.text("UI_ITEM_UNREAD", {"item": item})
		_add_row(id, item, id)

func _fill_corruption() -> void:
	for stat in PlayerStats.CORRUPTION:
		var level: int = inventory.corruption.get(stat, 0)
		var limit: int = PlayerStats.CORRUPTION[stat].limit
		_add_row(stat, "%s   %d/%d" % [_stat_name(stat), level, limit])

func _fill_codex() -> void:
	if codex == null:
		return
	if active_family == "ENEMIES":
		for id in GameData.ENEMIES:
			if id in codex.enemies:
				_add_row(id, loc.text(_enemy_key(id, "NAME")), id)
		return
	for id in codex.items:
		if _item_family(id) == active_family:
			var item := _item_name(id)
			if GameData.is_book(id) and not _has_read(id):
				item = loc.text("UI_ITEM_UNREAD", {"item": item})
			_add_row(id, item, id)

func _add_row(id: String, caption: String, icon_id := "") -> void:
	var icon := EditionArt.icon(icon_id) if not icon_id.is_empty() else null
	var index := entries.add_item(caption, icon)
	entries.set_item_metadata(index, id)
	if id == selected:
		entries.select(index)

func _content_top() -> float:
	return 194.0 if page == Page.CODEX else 151.0

func _refresh_selection() -> void:
	operation = ""
	action.position.y = 522.0
	action.theme_type_variation = &"PrimaryButton"
	action.hide()
	quick.hide()
	picture.hide()
	comparison.hide()
	detail_title.text = ""
	detail_title.position = Vector2(DETAIL_X, _content_top())
	detail_title.size.x = DETAIL_WIDTH
	detail.text = ""
	annotation.text = ""
	detail.position.y = _content_top() + 74.0
	detail.size.y = DETAIL_END - detail.position.y
	match page:
		Page.BAG: _show_item(false)
		Page.CORRUPTION: _show_corruption()
		Page.CRAFT: _show_recipe()
		Page.CODEX:
			if active_family == "ENEMIES" and not selected.is_empty():
				_show_enemy()
			else:
				_show_item(true)
	detail.scroll_to_line(0)

func _show_item(from_codex: bool) -> void:
	if selected.is_empty():
		detail_title.text = loc.text("UI_CODEX_EMPTY" if from_codex else "UI_BAG_EMPTY")
		return
	_set_entry_heading(_item_name(selected), selected)
	var stats_item := GameData.upgrade(selected)
	var values := {"value": int(GameData.POTION_HEAL)} if selected == "POTION" else {}
	if not stats_item.is_empty():
		values["value"] = GameData.effect_value(stats_item)
	detail.text = loc.text(GameData.description_key(selected), values)
	var weapon: Dictionary = PlayerStats.WEAPONS.get(selected, {})
	if not weapon.is_empty():
		var range_name: String = loc.text("UI_ATTACK_%s" % weapon.range_type.to_upper())
		var damage_name: String = loc.text("UI_DAMAGE_%s" % weapon.damage_type.to_upper())
		detail.text += "\n\n" + loc.text("UI_WEAPON_TYPES", {"range": range_name, "damage": damage_name})
	if not stats_item.is_empty():
		var effect := "ITEM_%s_EFFECT" % selected
		if GameData.description_key(selected) != effect:
			detail.text += "\n\n" + loc.text(effect, values)
	if GameData.is_book(selected):
		annotation.text = loc.text("UI_BOOK_READ") if _has_read(selected) else ""
		_set_action("read", "UI_READ")
		return
	if from_codex:
		return
	if selected == "POTION":
		var have_potion := inventory.count(selected) > 0
		_set_action("drink", "UI_DRINK", have_potion and hero.hp < hero.max_hp)
		annotation.text = loc.text("UI_HP_FULL") if have_potion and hero.hp >= hero.max_hp else ""
		quick.text = loc.text("UI_QUICK_REMOVE" if inventory.potion_on_quick_slot else "UI_QUICK_ASSIGN",
			{"quick": loc.binding("quick_item")})
		quick.show()
	elif not GameData.slot_for(selected).is_empty():
		_show_equipment_comparison()
		var equipped := selected in inventory.equipped.values()
		if not weapon.is_empty():
			_set_action("unequip" if equipped else "equip", "UI_UNEQUIP" if equipped else "UI_SET_CURRENT_WEAPON")
		else:
			_set_action("unequip" if equipped else "equip", "UI_UNEQUIP" if equipped else "UI_EQUIP")

func _show_equipment_comparison() -> void:
	var candidate := inventory.equipped.duplicate()
	var slot := GameData.slot_for(selected)
	if candidate.get(slot) == selected:
		candidate.erase(slot)
	else:
		candidate[slot] = selected
	var current := PlayerStats.calculate(inventory.equipped, inventory.corruption, inventory.boon_levels())
	var next := PlayerStats.calculate(candidate, inventory.corruption, inventory.boon_levels())
	for child in comparison.get_children():
		comparison.remove_child(child)
		child.queue_free()
	_comparison_row("", loc.text("UI_EQUIPMENT_CURRENT"), loc.text("UI_EQUIPMENT_CHANGE"), ui.GOLD)
	for stat: String in COMPARED_STATS:
		var before: float = current[stat]
		var diff: float = next[stat] - before
		var change := "0"
		if not is_zero_approx(diff):
			match stat:
				"critical": change = "%+.0f%%" % (diff * 100.0)
				"lifesteal": change = "%+.0f HP" % diff
				"speed": change = loc.text("UI_SPEED_VALUE", {"speed": "%+.1f" % diff})
				_: change = "%+.1f" % diff
		_comparison_row(_stat_name(stat), _stat_value(stat, before), change, _change_color(diff))
	_compare_intervals("START_SWORD", "UI_STAT_MELEE_INTERVAL", current, next, candidate.get("weapon", ""))
	_compare_intervals("START_STAFF", "UI_STAT_MAGIC_INTERVAL", current, next, candidate.get("weapon", ""))
	detail.size.y = 58.0
	action.position.y = 554.0
	comparison.show()

func _compare_intervals(reference: String, label_key: String, current: Dictionary, next: Dictionary, candidate: String) -> void:
	var range_type: String = PlayerStats.WEAPONS[reference].range_type
	var equipped := inventory.current_weapon()
	var before_weapon := _weapon_of_type(equipped, range_type, reference)
	var after_weapon := _weapon_of_type(candidate, range_type, reference)
	var before := PlayerStats.attack_interval(before_weapon, current)
	var after := PlayerStats.attack_interval(after_weapon, next)
	var delta := after - before
	var difference := "0.00" if is_zero_approx(delta) else "%+.2f" % delta
	_comparison_row(loc.text(label_key), _interval_value("%.2f" % before), _interval_value(difference), _change_color(-delta))

func _weapon_of_type(weapon: String, range_type: String, fallback: String) -> String:
	return weapon if PlayerStats.WEAPONS.get(weapon, {}).get("range_type") == range_type else fallback

func _change_color(value: float) -> Color:
	if is_zero_approx(value):
		return ui.MUTED
	return Color("a9ccad") if value > 0.0 else Color("ed9b92")

func _comparison_row(caption: String, current: String, change: String, tint: Color) -> void:
	var columns := [caption, current, change]
	var widths := [180.0, 97.0, 124.0]
	for index in range(columns.size()):
		var label := Label.new()
		label.text = columns[index]
		label.clip_text = true
		label.custom_minimum_size.x = widths[index]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", tint if index == 2 else ui.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if index == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		comparison.add_child(label)

func _show_enemy() -> void:
	_set_entry_heading(loc.text(_enemy_key(selected, "NAME")), selected)
	var data: Dictionary = GameData.ENEMIES[selected]
	detail.text = loc.text(_enemy_key(selected, "DESC"), data)
	if selected == "lord" and (_has_read("LORE_F1") or _has_read("LORE_ORDER")) and (_has_read("LORE_RESEARCH") or _has_read("LORE_TRIAL")):
		detail.text += "\n\n" + loc.text("ENEMY_LORD_IDENTITY")
	annotation.text = loc.text("UI_CODEX_ENEMY_HP", {"hp": int(data.hp)})

func _show_corruption() -> void:
	var current := PlayerStats.calculate(inventory.equipped, inventory.corruption, inventory.boon_levels())
	var levels := inventory.corruption.duplicate()
	var level: int = levels.get(selected, 0)
	var at_limit: bool = level >= PlayerStats.CORRUPTION[selected].limit
	if not at_limit:
		levels[selected] = level + 1
	var preview := PlayerStats.calculate(inventory.equipped, levels, inventory.boon_levels())
	_set_entry_heading(_stat_name(selected), "pearl")
	detail.text = loc.text("UI_CORRUPTION_BALANCE", {"count": inventory.blood_beads}) + "\n\n"
	var weapon := inventory.current_weapon()
	if selected == "interval":
		if weapon.is_empty():
			detail.text += loc.text("UI_STAT_MELEE_INTERVAL") + "\n" + _interval_preview("START_SWORD", current, preview)
			detail.text += "\n\n" + loc.text("UI_STAT_MAGIC_INTERVAL") + "\n" + _interval_preview("START_STAFF", current, preview)
		else:
			detail.text += _interval_preview(weapon, current, preview)
	else:
		detail.text += _stat_preview(_stat_value(selected, current[selected]), _stat_value(selected, preview[selected]))
	if at_limit:
		annotation.text = loc.text("UI_CORRUPTION_MAX")
	elif inventory.blood_beads == 0:
		annotation.text = loc.text("UI_CORRUPTION_EMPTY")
	_set_action("enhance", "UI_CORRUPTION_CONFIRM", magic_allowed and inventory.can_enhance(selected))
	action.theme_type_variation = &"BloodButton"

func _stat_preview(current: String, preview: String) -> String:
	return loc.text("UI_CORRUPTION_PREVIEW", {"current": current, "preview": preview})

func _interval_preview(weapon: String, current: Dictionary, preview: Dictionary) -> String:
	var current_time := _interval_value("%.2f" % PlayerStats.attack_interval(weapon, current))
	var next_time := _interval_value("%.2f" % PlayerStats.attack_interval(weapon, preview))
	return _stat_preview(current_time, next_time)

func _interval_value(value: String) -> String:
	return loc.text("UI_INTERVAL_VALUE", {"time": value})

func _stat_value(stat: String, value: float) -> String:
	match stat:
		"critical": return "%d%%" % roundi(value * 100.0)
		"lifesteal": return "%d HP" % roundi(value)
		"speed": return loc.text("UI_SPEED_VALUE", {"speed": "%.1f" % value})
		_: return str(roundi(value))

func _stat_name(stat: String) -> String:
	if stat == "interval":
		var weapon: Dictionary = PlayerStats.WEAPONS.get(inventory.current_weapon(), {})
		match weapon.get("range_type"):
			"melee": return loc.text("UI_STAT_MELEE_INTERVAL")
			"ranged": return loc.text("UI_STAT_MAGIC_INTERVAL")
	return loc.text("UI_STAT_%s" % stat.to_upper())

func _show_recipe() -> void:
	_set_entry_heading(_item_name("POTION"), "POTION")
	for child in recipe_materials.get_children():
		recipe_materials.remove_child(child)
		child.queue_free()
	var heading := Label.new()
	heading.text = loc.text("UI_CRAFT_MATERIALS")
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", ui.GOLD)
	recipe_materials.add_child(heading)
	var missing: Array[String] = []
	for id in RunInventory.POTION_RECIPE:
		var need: int = RunInventory.POTION_RECIPE[id]
		var current := inventory.count(id)
		var item := _item_name(id)
		var row := Panel.new()
		row.custom_minimum_size.y = 57
		row.add_theme_stylebox_override("panel", ui._box(ui.INSET, ui.RULE))
		recipe_materials.add_child(row)
		var material := ui._label(row, Vector2(57, 0), Vector2(LIST_WIDTH - 69, 57), 16, ui.INK, HORIZONTAL_ALIGNMENT_LEFT, true) as Label
		material.text = loc.text("UI_CRAFT_MATERIAL", {"item": item, "have": current, "need": need})
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2(12, 10)
		icon.size = Vector2(37, 37)
		icon.texture = EditionArt.icon(id)
		row.add_child(icon)
		if current < need:
			missing.append(item)
	detail.text = loc.text("ITEM_POTION_EFFECT", {"value": int(GameData.POTION_HEAL)})
	detail.text += "\n\n" + loc.text("UI_CRAFT_YIELD", {"count": inventory.count("POTION")})
	if not missing.is_empty():
		annotation.text = loc.text("UI_CRAFT_MISSING", {"items": " · ".join(missing)})
	_set_action("craft", "UI_CRAFT_POTION", inventory.can_craft())

func _set_entry_heading(caption: String, id: String) -> void:
	var icon := UpgradeArt.frame(id, "s", "idle", 0) if page == Page.CODEX and active_family == "ENEMIES" else null
	if icon == null:
		icon = EditionArt.icon(id)
	picture.texture = icon
	picture.visible = icon != null
	detail_title.text = caption
	picture.position = Vector2(DETAIL_X, _content_top() + 6.0)
	var icon_size := 105.0 if page == Page.CODEX else 91.0
	picture.size = Vector2(icon_size, icon_size)
	if picture.visible:
		detail_title.position.x = DETAIL_X + 112.0
		detail_title.size.x = DETAIL_WIDTH - 112.0
		detail_title.position.y = _content_top() + 14.0
		detail.position.y = _content_top() + 109.0
		detail.size.y = DETAIL_END - detail.position.y

func _set_action(action_id: String, key: String, enabled := true) -> void:
	operation = action_id
	action.text = loc.text(key)
	action.disabled = not enabled
	action.show()

func _item_name(id: String) -> String:
	return loc.text(GameData.name_key(id))

func _has_read(id: String) -> bool:
	return (inventory != null and id in inventory.read) or (codex != null and id in codex.read)

func _enemy_key(id: String, part: String) -> String:
	return "ENEMY_%s_%s" % [id.to_upper(), part]

func _item_family(id: String) -> String:
	if GameData.is_book(id):
		return "MANUSCRIPTS"
	return "SUPPLIES" if id in GameData.STACKABLE else "EQUIPMENT"

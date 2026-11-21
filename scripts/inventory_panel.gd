extends Control

signal item_requested(operation: String, id: String)
signal crafting_requested

const GameData = preload("res://data/game_data.gd")
var ui: CanvasLayer
var loc: Node
var inventory: RunInventory
var title: Label
var owned_title: Label
var slot_title: Label
var slot_labels: Dictionary = {}
var slot_values: Dictionary = {}
var items: ItemList
var detail: Label
var action: Button
var quick: Button
var craft: Button
var back: Button
var selected := ""
var operation := ""
var hero: Node2D

func setup(interface: CanvasLayer, service: Node) -> void:
	ui = interface
	loc = service
	ui._dimmer(self, 0.83)
	ui._panel(self, Rect2(202, 55, 876, 610), Color("212932"), Color("8c7554"))
	title = ui._label(self, Vector2(244, 78), Vector2(792, 47), 28, ui.GOLD)
	ui._color(self, Rect2(244, 135, 792, 1), Color("685943"))
	owned_title = ui._label(self, Vector2(244, 148), Vector2(394, 28), 16, ui.INK)
	slot_title = ui._label(self, Vector2(669, 148), Vector2(367, 28), 16, ui.INK)
	items = ItemList.new()
	items.name = "Items"
	items.position = Vector2(244, 186)
	items.size = Vector2(385, 322)
	items.add_theme_constant_override("v_separation", 11)
	items.add_theme_color_override("font_color", ui.INK)
	add_child(items)
	items.item_selected.connect(func(index: int):
		selected = str(items.get_item_metadata(index))
		_refresh_selection())
	for i in range(GameData.SLOTS.size()):
		var slot: String = GameData.SLOTS[i]
		var y := 186 + i * 42
		ui._panel(self, Rect2(669, y, 367, 36), Color("2b3440"), Color("505257"))
		slot_labels[slot] = ui._label(self, Vector2(682, y), Vector2(105, 36), 13, ui.MUTED)
		slot_values[slot] = ui._label(self, Vector2(786, y), Vector2(234, 36), 15, ui.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	detail = ui._label(self, Vector2(669, 443), Vector2(367, 73), 15, ui.INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	action = ui._button(self, "ItemAction", Rect2(669, 524, 367, 44), true)
	action.pressed.connect(func(): item_requested.emit(operation, selected))
	quick = ui._button(self, "QuickSlot", Rect2(669, 578, 367, 42))
	quick.pressed.connect(func(): item_requested.emit("quick", selected))
	craft = ui._button(self, "Crafting", Rect2(244, 526, 385, 44), true)
	craft.pressed.connect(func(): crafting_requested.emit())
	back = ui._button(self, "Back", Rect2(244, 578, 385, 42))
	back.pressed.connect(func(): ui.close_requested.emit())

func show_inventory(model: RunInventory, player: Node2D) -> void:
	if inventory != model:
		selected = ""
	inventory = model
	hero = player
	refresh()

func refresh() -> void:
	if inventory == null:
		return
	title.text = loc.text("UI_BAG_TITLE")
	owned_title.text = loc.text("UI_BAG_ITEMS")
	slot_title.text = loc.text("UI_BAG_EQUIPPED")
	craft.text = loc.text("UI_CRAFT_TITLE")
	back.text = loc.text("UI_BACK")
	for slot in GameData.SLOTS:
		var id: String = inventory.equipped.get(slot, "")
		slot_labels[slot].text = loc.text("UI_SLOT_%s" % slot.to_upper())
		slot_values[slot].text = loc.text("UI_SLOT_EMPTY") if id.is_empty() else loc.text(GameData.name_key(id))
	items.clear()
	for id in GameData.STACKABLE:
		if inventory.count(id) > 0 or (id == "POTION" and inventory.potion_on_quick_slot):
			_add_row(id, "%s  ×%d" % [loc.text(GameData.name_key(id)), inventory.count(id)])
	for id in inventory.owned:
		var name: String = loc.text(GameData.name_key(id))
		if inventory.equipped.get(GameData.slot_for(id), "") == id:
			name = loc.text("UI_ITEM_EQUIPPED", {"item": name})
		_add_row(id, name)
	if not items.is_anything_selected():
		selected = ""
		if items.item_count > 0:
			items.select(0)
			selected = str(items.get_item_metadata(0))
	items.ensure_current_is_visible()
	_refresh_selection()

func _add_row(id: String, name: String) -> void:
	var index := items.add_item(name)
	items.set_item_metadata(index, id)
	if id == selected:
		items.select(index)

func _refresh_selection() -> void:
	operation = ""
	var button_text := ""
	var enabled := true
	quick.visible = selected == "POTION"
	if selected == "POTION":
		detail.text = loc.text("ITEM_POTION_EFFECT", {"value": int(GameData.POTION_HEAL)})
		operation = "drink"
		button_text = "UI_DRINK"
		enabled = inventory.count(selected) > 0 and hero.hp < hero.max_hp
		quick.text = loc.text("UI_QUICK_REMOVE" if inventory.potion_on_quick_slot else "UI_QUICK_ASSIGN",
			{"quick": loc.binding("quick_item")})
	elif selected in GameData.STACKABLE:
		detail.text = loc.text("UI_ITEM_INGREDIENT")
	elif GameData.is_book(selected):
		detail.text = loc.text("UI_BOOK_READ" if selected in inventory.read else "UI_BOOK_UNREAD")
		operation = "read"
		button_text = "UI_READ"
	elif not selected.is_empty():
		var item := GameData.upgrade(selected)
		detail.text = loc.text("UI_STARTER_WEAPON") if item.is_empty() else loc.text("ITEM_%s_EFFECT" % selected, {"value": GameData.effect_value(item)})
		var worn: bool = inventory.equipped.get(GameData.slot_for(selected), "") == selected
		if not item.is_empty() or not worn:
			operation = "unequip" if worn else "equip"
			button_text = "UI_UNEQUIP" if worn else "UI_EQUIP"
	else:
		detail.text = loc.text("UI_BAG_EMPTY")
	action.visible = not operation.is_empty()
	action.disabled = not enabled
	if action.visible:
		action.text = loc.text(button_text)

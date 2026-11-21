class_name FloorDefinition
extends Resource

@export_group("Entry")
@export var tip_key := ""
@export var entry_note_key := ""
@export var wait_for_confirmation := false

@export_group("Combat")
## Lists enemy type IDs for each wave, in spawn order.
@export var waves: Array[PackedStringArray] = []
## When set, defeating this enemy type clears the encounter, including surviving enemies.
@export var clear_on_enemy_defeat := ""
@export var obstacle_count := 4
@export var keep_center_open := false

@export_group("After Clear")
## World position to item ID for guaranteed pickups after the floor is clear.
@export var clear_pickups: Dictionary[Vector2, String] = {}
## When set, continuing after the floor shows this book instead of a reward.
@export var epilogue := ""

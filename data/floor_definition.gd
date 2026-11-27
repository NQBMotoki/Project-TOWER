class_name FloorDefinition
extends Resource

@export_group("Entry")
@export var tip_key := ""
@export var entry_note_key := ""
## When true the floor waits for confirm before the fight starts.
@export var wait_for_confirmation := true

@export_group("Combat")
## Lists enemy type IDs for each wave, in spawn order.
@export var waves: Array[PackedStringArray] = []
@export var obstacle_count := 4
@export var keep_center_open := false

@export_group("After Clear")
## World position to item ID for guaranteed pickups after the floor is clear.
@export var clear_pickups: Dictionary[Vector2, String] = {}

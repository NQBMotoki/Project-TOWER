class_name FloorDefinition
extends Resource

enum AfterClear { REWARD, OPTIONAL_RECORD, EPILOGUE }

@export_group("Entry")
@export var tip_key := ""
@export var entry_note_key := ""
@export var wait_for_confirmation := false

@export_group("Combat")
## Lists enemy type IDs for each wave, in spawn order.
@export var waves: Array[PackedStringArray] = []
## When set, defeating this enemy type clears the encounter, including surviving enemies.
@export var clear_on_enemy_defeat := ""

@export_group("After Clear")
@export var after_clear: AfterClear = AfterClear.REWARD
@export var record_title_key := ""
@export var record_body_key := ""
@export var record_position := Vector2.ZERO

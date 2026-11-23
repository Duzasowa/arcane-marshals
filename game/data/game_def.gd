class_name GameDef
extends Resource

## Base of every data definition: an id unique within its type and the text keys.
## Definitions refer to each other by id, never by Resource, so the validator
## checks every link the same way and a save stores plain ids.

@export var id: StringName = &""
## Key into data/text/*.csv; required.
@export var name_key: StringName = &""
## Key into data/text/*.csv; optional.
@export var desc_key: StringName = &""

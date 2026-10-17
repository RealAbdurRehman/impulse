class_name LookStyle
extends Resource
## What a character is wearing. Swap the resource to get another look.

@export_group("Colours")
@export var uniform := Color(0.5, 0.52, 0.54)
@export var vest := Color(0.62, 0.64, 0.62)
@export var pouch := Color(0.46, 0.48, 0.46)
@export var helmet := Color(0.17, 0.18, 0.2)
@export var mask := Color(0.2, 0.21, 0.24)
@export var skin := Color(0.8, 0.62, 0.5)
@export var glove := Color(0.24, 0.24, 0.26)
@export var boot := Color(0.24, 0.24, 0.26)
@export var pad := Color(0.26, 0.27, 0.29)
@export var tag := Color(0.88, 0.88, 0.84)

@export_group("Gear")
@export var helmet_on := true
@export var vest_on := true
@export var backpack_on := true
@export var pads_on := true
@export var pockets_on := true

@export_group("Build")
@export_range(0.8, 1.3) var bulk := 1.0

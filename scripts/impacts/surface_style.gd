class_name SurfaceStyle
extends Resource

enum Mark { NONE, CONCRETE, METAL, WOOD, GLASS, PLASTIC }

@export var resistance := 1.0

@export_group("Dust")
@export var dust_color := Color(0.72, 0.71, 0.68)
@export_range(0.0, 1.0) var dust_density := 0.5
@export_range(0.0, 20.0) var dust_count := 0.0
@export var dust_length := Vector2(0.03, 0.14)
@export_range(0.1, 1.0) var dust_width := 0.4
@export var dust_speed := Vector2(0.6, 2.4)
@export var dust_life := Vector2(0.5, 1.0)
@export_range(-1.0, 1.0) var dust_rise := 0.15
@export_range(0.0, 1.0) var dust_grain := 0.0
@export_range(0.0, 1.0) var dust_forward := 0.15

@export_group("Debris")
@export_range(0.0, 30.0) var debris_count := 0.0
@export var debris_colors: Array[Color] = []
@export var debris_size := Vector2(0.006, 0.018)
@export var debris_shape := Vector3(1.0, 0.7, 0.5)
@export var debris_speed := Vector2(1.5, 5.5)
@export_range(0.0, 0.9) var debris_bounce := 0.3
@export var debris_glass := false

@export_group("Sparks")
@export_range(0.0, 30.0) var spark_count := 0.0
@export var spark_color := Color(1.0, 0.72, 0.3)
@export var spark_speed := Vector2(2.5, 8.0)
@export_range(0.0, 2.0) var flash := 0.0
@export_range(0.0, 1.0) var ricochet := 1.0

@export_group("Mark")
@export var mark := Mark.NONE
@export var mark_size := 0.1
@export var mark_color := Color(0.8, 0.8, 0.78)

@export_group("Tint")
@export var tinted := false

@export_group("Sound")
@export var sound: SoundSet

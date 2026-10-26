class_name GameSettings
extends Resource

enum Quality {
	LOW,
	MEDIUM,
	HIGH,
}

const PATH := "user://settings.tres"
const SCALE := [0.67, 0.85, 1.0]
const SHADOW_SIZE := [1024, 2048, 4096]

static var current := _load()

@export var quality := Quality.HIGH
@export var fullscreen := false
@export var vsync := true
@export_range(0.0, 1.0) var volume := 1.0
@export var blood := true
@export var dismemberment := true
@export_range(0.0, 1.5) var effects := 1.0
@export var indicators := true


static func _load() -> GameSettings:
	if ResourceLoader.exists(PATH):
		return ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)

	var fresh := GameSettings.new()
	if OS.has_feature("web"):
		fresh.quality = Quality.MEDIUM

	return fresh


func save() -> void:
	ResourceSaver.save(self, PATH)


func shadows() -> bool:
	return quality != Quality.LOW


func apply(viewport: Viewport) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = SCALE[quality]
	viewport.msaa_3d = Viewport.MSAA_2X if quality == Quality.HIGH else Viewport.MSAA_DISABLED
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZE[quality], true)

	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	AudioServer.set_bus_mute(0, volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))

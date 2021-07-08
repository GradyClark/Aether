extends Spatial

signal on_hit (spatial_hit, spatial_from)
signal on_kill (spatial_killed, spatial_from)

export (float) var weapon_damage
export (Vector3) var weapon_range
export (NodePath) var weapon_raycast_node
export (NodePath) var actor
export (NodePath) var total_ammo_display
export (NodePath) var clip_ammo_display
export (bool) var automatic = false
export (float) var delay_between_shots_ms = 1
export var override_automatic_firerate = false 
export (float) var override_firerate_delay_ms = 0

export var unlimited_ammo = false
export var total_ammo = 0
export var bottomless_clips = false
export var clip_can_hold = 0
export (float) var reload_time_ms = 1000
export var ammo_in_clip = 0

export (String) var Weapon_Name = ""

var reload_timer: Timer = null
var _weapon_raycast: RayCast
var _actor
var _total_ammo_display: Label
var _clip_ammo_display: Label

var has_shot_once = false
var last_shot_time = OS.get_ticks_msec()
var auto_timer: Timer = null

func _ready():
	_weapon_raycast = get_node(weapon_raycast_node)
	_weapon_raycast.cast_to = weapon_range
	_actor = get_node(actor)
	set_display_nodes(total_ammo_display, clip_ammo_display)
	
	auto_timer = Timer.new()
	auto_timer.name = "auto_timer"
	if override_automatic_firerate:
		auto_timer.wait_time = override_firerate_delay_ms/1000
	else:
		auto_timer.wait_time = delay_between_shots_ms/1000
	auto_timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
	auto_timer.connect("timeout", self, "_shoot")
	add_child(auto_timer)
	
	reload_timer = Timer.new()
	reload_timer.name = "reload_timer"
	reload_timer.wait_time = reload_time_ms/1000
	reload_timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
	reload_timer.connect("timeout", self, "_reload")
	reload_timer.stop()
	add_child(reload_timer)
	
	refresh_displays()

func set_display_nodes(total:NodePath, clip:NodePath):
	_total_ammo_display = get_node(total)
	_clip_ammo_display = get_node(clip)
	refresh_displays()
	
func refresh_displays():
	if _total_ammo_display != null:
		if unlimited_ammo:
			_total_ammo_display.text = "Unlimited"
		else:
			_total_ammo_display.text = str(total_ammo)
			
	if _clip_ammo_display != null:
		if bottomless_clips:
			_clip_ammo_display.text = "Bottomless"
		else:
			_clip_ammo_display.text = str(ammo_in_clip)

remotesync func _sound_effect():
	$RayCast/sound.play()

func _shoot():
	if not reload_timer.is_stopped():
		return
	if unlimited_ammo and bottomless_clips:
		pass
	elif bottomless_clips:
		if total_ammo <= 0:
			return
		total_ammo -= 1
	elif unlimited_ammo:
		if ammo_in_clip <= 0:
			return
		ammo_in_clip -= 1
	refresh_displays()
	has_shot_once = true
	last_shot_time = OS.get_ticks_msec()
	rpc("_sound_effect")
	var target = _weapon_raycast.get_collider()
	if target != null and not target.is_in_group(Globals.GROUP_PLAYERS):
		emit_signal("on_hit", target, _actor)
		if target.is_in_group(Globals.GROUP_DESTROYABLE):
			var info = target.get_node("destroyable")
			info.change_health_by(-weapon_damage)
			if info.health <= 0:
				emit_signal("on_kill", target, _actor)
		


func trigger_pulled():
	var n = OS.get_ticks_msec()
	
	if automatic and auto_timer.is_stopped():
		auto_timer.start()
	
	if n - last_shot_time > delay_between_shots_ms:
		if has_shot_once and automatic:
			_shoot()
		elif not has_shot_once:
			_shoot()


func trigger_released():
	if not auto_timer.is_stopped():
		auto_timer.stop()
	has_shot_once = false

remotesync func _set_visible(new_value):
	visible = new_value

func reload():
	if reload_timer.is_stopped():
		reload_timer.start()
		rpc("_set_visible", false)

func _reload():
	if unlimited_ammo:
		ammo_in_clip = clip_can_hold
	elif total_ammo > 0:
		var n = 0
		if total_ammo >= clip_can_hold:
			n = clip_can_hold - ammo_in_clip
		else:
			n = max(0, total_ammo - ammo_in_clip)
		total_ammo -= n
		ammo_in_clip += n
	reload_timer.stop()
	refresh_displays()
	rpc("_set_visible", true)

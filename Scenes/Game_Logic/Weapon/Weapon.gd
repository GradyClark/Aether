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
export var max_total_ammo = 0
export var bottomless_clips = false
export var clip_can_hold = 0
export (float) var reload_time_ms = 1000
export var ammo_in_clip = 0

export (String) var Weapon_Name = ""

export (NodePath) var Node_Sound_Shot
export (NodePath) var Node_Sound_Reload
export (NodePath) var Node_Sound_Cycling
export (NodePath) var Node_Sound_Empty

var reload_timer: Timer = null
var _weapon_raycast: RayCast
var _actor
var _total_ammo_display: Label
var _clip_ammo_display: Label

var has_shot_once = false
var last_shot_time = OS.get_ticks_msec()
var auto_timer: Timer = null

var _node_sound_shot
var _node_sound_reload
var _node_sound_cycling
var _node_sound_empty

enum Sound_Effects {shot, reload, cycle, click}

func _ready():
	_weapon_raycast = get_node(weapon_raycast_node)
	_weapon_raycast.cast_to = weapon_range
	_actor = get_node(actor)
	set_display_nodes(total_ammo_display, clip_ammo_display)
	
	_node_sound_shot = get_node_or_null(Node_Sound_Shot)
	_node_sound_reload = get_node_or_null(Node_Sound_Reload)
	_node_sound_cycling = get_node_or_null(Node_Sound_Cycling)
	_node_sound_empty = get_node_or_null(Node_Sound_Empty)
	
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
#	ammo_in_clip = clip_can_hold
#	total_ammo = max_total_ammo

func set_display_nodes(total:NodePath, clip:NodePath):
	_total_ammo_display = get_node_or_null(total)
	_clip_ammo_display = get_node_or_null(clip)
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

remotesync func _sound_effect(effect): # self.Sound_Effects enum
	if effect == Sound_Effects.shot and _node_sound_shot != null:
		_node_sound_shot.play()
	elif effect == Sound_Effects.reload and _node_sound_reload != null:
		_node_sound_reload.play()
	elif effect == Sound_Effects.cycle and _node_sound_cycling != null:
		_node_sound_cycling.play()
	elif effect == Sound_Effects.click and _node_sound_empty != null:
		_node_sound_empty.play()

func _shoot():
	if not reload_timer.is_stopped():
		return
	if unlimited_ammo and bottomless_clips:
		pass
	elif bottomless_clips:
		if total_ammo <= 0:
			rpc("_sound_effect", Sound_Effects.click)
			return
		else:
			total_ammo -= 1
	else:
		if ammo_in_clip <= 0:
			rpc("_sound_effect", Sound_Effects.click)
			return
		ammo_in_clip -= 1
	refresh_displays()
	has_shot_once = true
	last_shot_time = OS.get_ticks_msec()
	rpc("_sound_effect", Sound_Effects.shot)
	var target = _weapon_raycast.get_collider()
	if target != null and not target.is_in_group(Globals.GROUP_PLAYERS):
		emit_signal("on_hit", target, _actor)
		if target.is_in_group(Globals.GROUP_DESTROYABLE):
			var info = target.get_node(Globals.GROUP_DESTROYABLE)
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
		rpc("_sound_effect", Sound_Effects.reload)

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

remotesync func set_ammo(_clip,_total):
	ammo_in_clip = _clip
	total_ammo = _total
	
	if ammo_in_clip < 0:
		ammo_in_clip = 0
	elif ammo_in_clip > clip_can_hold:
		ammo_in_clip = clip_can_hold
	
	if total_ammo < 0:
		total_ammo = 0
	elif total_ammo > max_total_ammo:
		total_ammo = max_total_ammo
	

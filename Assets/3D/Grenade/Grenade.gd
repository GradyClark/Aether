extends RigidBody

export (int) var explosion_radius = 15
export (int) var falloff_start = 5
export (int) var damage = 1000 
export (int) var fuse = 5

var _player_id:int = -1

var SID="Grenade"

onready var perk_demoman = Globals.Perk_Demoman.new()

func serialize():
	return {"SID":SID, "name": name}


func deserialize(data):
	pass


func _ready():
	$explosion_radius/CollisionShape.shape.set_radius(explosion_radius)
	$fuse.wait_time = fuse
	$fuse.stop()
#	if not is_network_master():
#		self.mode = RigidBody.MODE_KINEMATIC
	
	if Networking.is_server():
		Globals.connect("when_player_removed", self, "_when_player_removed")

func _exit_tree():
	Globals.disconnect("when_player_removed", self, "_when_player_removed")

func _when_player_removed(p):
	if p.ID == str(_player_id):
		_on_delete_timeout()
	

func trigger(player_id: int = -1):
	if $fuse.is_stopped():
		$fuse.start()
	_player_id = player_id


func _on_fuse_timeout():
	rpc("_phase_2")
	var nodes = $explosion_radius.get_overlapping_bodies()
	for node in nodes:
		if node.is_in_group(Globals.GROUP_DESTROYABLE):
			if node.is_in_group(Globals.GROUP_PLAYERS) and node.get_node("Player_Controller").player.get_perk(perk_demoman.Product_ID) != null:
				continue
				
			var dis = global_transform.origin.distance_to(node.global_transform.origin)
			var dmg = damage
			if dis >= falloff_start:
				dmg = (1 - (dis - falloff_start) / (explosion_radius - falloff_start)) * damage
			if dmg > 0:
				node.get_node(Globals.GROUP_DESTROYABLE).change_health_by(-dmg)
				if _player_id > 0 and node.is_in_group(Globals.GROUP_ENEMIES):
					var v = 10
					if node.get_node(Globals.GROUP_DESTROYABLE).is_dead:
						v+=100
					var _p = Globals.get_player_with_id(_player_id)
					if _p != null:
						Globals.player_set_points(str(_player_id), _p.Points + v)


func _on_delete_timeout():
	queue_free()


remotesync func _phase_2():
	hide()
	_play_explosion_sound()
	$delete.start()


remotesync func _play_explosion_sound():
	$Sound_Explosion.play()


puppet func _set_transform(_global_transform):
	if mode != MODE_KINEMATIC and not get_tree().is_network_server():
		mode = MODE_KINEMATIC
	global_transform = _global_transform


func _physics_process(delta):
	if is_network_master():
		rpc_unreliable("_set_transform", global_transform)

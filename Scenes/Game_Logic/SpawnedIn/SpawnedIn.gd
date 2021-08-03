extends Node

func _ready():
	Globals.node_spawnedin = self
	Globals.node_spawnedin_synced = $Synced
	Globals.node_spawnedin_unsynced = $Unsynced
	
	if Networking.is_server():
		Globals.connect("send_client_map_setup_info", self, "_send_client_map_setup_info")

func _exit_tree():
	Globals.node_spawnedin = null
	Globals.node_spawnedin_synced = null
	Globals.node_spawnedin_unsynced = null


func _send_client_map_setup_info(id):
#	var data = []
#	for node in $Synced.get_children():
#		data.append(node.serialize())
#	rpc_id(id,"_server_set_game_data", data)

	var data = []
	for node in $Synced.get_children():
		#zombie
		if node.SID == Globals.pl_blockhead_character.SID:
			# Assume it's a zombie, for now
			data.append([node.serialize(),node.get_node(Globals.GROUP_DESTROYABLE).serialize(), node.get_node("AI_Controller").serialize()])
			
		elif node.SID == Globals.pl_grenade.SID:
			data.append([node.serialize()])
			
#			var z = Globals.pl_blockhead_character.duplicate()
#			$Synced.add_child(z)
#			z.deserialize()
		#grenade

	rpc_id(id, "_server_sent_game_data", data)

remote func _server_sent_game_data(data:Array):
#	var done = false
#	for x in data:
#		done = false
#		for s in Globals.serializables:
#			if s.SID == x.SID:
#				var y = s.duplicate()
#				y.deserialize(x)
#				$Synced.add_child(y)
#				done = true
#				break
#		if not done:
#			if x.SID == Globals.pl_blockhead_character:
#				# Just assume it's a zombie, for now
#				var z = Globals.ai_zombie.instance()
#
#				pass

	for d in data:
		if d[0].SID == Globals.pl_blockhead_character.SID:
			#assume it's a zombie, for now
			var z = Globals.ai_zombie.instance()
			z.name = d[0].name
			$Synced.add_child(z)
			z.deserialize(d[0])
			z.get_node(Globals.GROUP_DESTROYABLE).deserialize(d[1])
			z.get_node("AI_Controller").deserialize(d[2])
		elif d[0].SID == Globals.pl_grenade.SID:
			var g = Globals.pl_grenade.duplicate()
			g.name = d[0].name
			$Synced.add_child(g)
			g.deserialize(d[0])

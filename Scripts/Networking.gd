extends Node

signal on_player_registered (user_name, id)
signal on_connection_failed ()
signal on_server_disconnected ()

var upnp: UPNP = UPNP.new()
var default_port: int = 4000
var my_peer_id = null
var opened_ports = []
var upnp_discovery_ran = false


func upnp_discovery():
	if not upnp_discovery_ran:
		upnp.discover(2000, 2, "InternetGatewayDevice")
		upnp_discovery_ran = true


func upnp_open_port(port: int = default_port):
	upnp_discovery()
	
	var gate = upnp.get_gateway()
	
	if gate == null:
		return UPNP.UPNP_RESULT_NO_GATEWAY
	elif not gate.is_valid_gateway():
		return UPNP.UPNP_RESULT_INVALID_GATEWAY
	
	var r = upnp.add_port_mapping(port, 0, "Aether Multiplayer", "UDP")
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		opened_ports.append(port)
		
	return r


func upnp_close_port(port: int = default_port):
	upnp_discovery()
	
	var gate = upnp.get_gateway()
	
	if gate == null:
		return UPNP.UPNP_RESULT_NO_GATEWAY
	elif not gate.is_valid_gateway():
		return UPNP.UPNP_RESULT_INVALID_GATEWAY
		
	var r = upnp.delete_port_mapping(port)
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		opened_ports.erase(port)
	
	return r


func upnp_get_external_ip():
	upnp_discovery()
	
	return upnp.query_external_address()


func _connect_all():
	if get_tree().network_peer != null:
		get_tree().network_peer.connect("peer_connected", self, "_network_peer_connected")
		get_tree().network_peer.connect("peer_disconnected", self, "_network_peer_disconnected")
		get_tree().network_peer.connect("server_disconnected", self, "_network_server_disconnected")
		get_tree().network_peer.connect("connection_failed", self, "_network_connection_failed")
		get_tree().network_peer.connect("connection_succeeded", self, "_network_connection_succeeded")


func _disconnect_incoming_signals():
	if get_tree().network_peer != null:
		close_connection()
		get_tree().network_peer.disconnect("peer_connected", self, "_network_peer_connected")
		get_tree().network_peer.disconnect("peer_disconnected", self, "_network_peer_disconnected")
		get_tree().network_peer.disconnect("server_disconnected", self, "_network_server_disconnected")
		get_tree().network_peer.disconnect("connection_failed", self, "_network_connection_failed")
		get_tree().network_peer.disconnect("connection_succeeded", self, "_network_connection_succeeded")


func _disconnect_outgoing_signals():
	Globals.universal_disconnect_helper(self, ["on_player_registered", "on_connection_failed", "on_server_disconnected"])

func _exit_tree():
	clean_up()


func clean_up():
	close_connection()
	_disconnect_incoming_signals()
	_disconnect_outgoing_signals()
	get_tree().network_peer = null
	
	for p in opened_ports:
		upnp_close_port(p)


func _network_peer_connected(id):
	# This gets called for every peer currently connected, and those trying to connect
	print("_network_player_connected")


func _network_peer_disconnected(id):
	# This gets called for every peer that disconnects
	print("_network_player_disconnected")
	Globals.rpc("remove_player_with_id", str(id)) 


func _network_server_disconnected():
	# Clients only get this one
	print("_network_server_disconnected")
	Dialog.display("Server Disconnected","")
	emit_signal("on_server_disconnected")


func _network_connection_failed():
	# Clients only get this one
	print("_network_connection_failed")
	emit_signal("on_connection_failed")


func _network_connection_succeeded():
	# This only triggers for clients, after "_network_peer_connected" (server), then this, then "_network_peer_connected" (for each of the other clients)
	print("_network_connection_succeeded")
	
	var my_user_name = Globals.players[0].Name
	var game_version = ProjectSettings.get_setting("application/config/version")
	
	rpc_id(1, "_register_client", my_user_name, game_version)


remote func _register_client(user_name, game_version):
	var id = get_tree().get_rpc_sender_id()
	if game_version == ProjectSettings.get_setting("application/config/version"):
#		rpc_id(get_tree().get_rpc_sender_id(), "_add_player", Globals.players[0].Name, my_peer_id)
		for p in Globals.players:
			rpc_id(id, "_add_player", p.Name, p.ID) # Add existing players to new client
		rpc("_add_player", user_name, id)# Add new player to existing clients
		emit_signal("on_player_registered", user_name, str(id))
	else:
		Globals.remove_player_with_id(str(id))


remotesync func _add_player(user_name, id):
	var p:Globals.Player = Globals.Player.new()
	if str(id) == str(my_peer_id):
		p = Globals.players[0]
		
	p.Name = user_name
	p.ID = str(id)
	
	if str(id) != str(my_peer_id):
		Globals.add_player(p)


func close_connection():
	if is_network_connected():
		get_tree().network_peer.close_connection()
		
		while Globals.players.size() > 1:
			Globals.remove_player_with_id(Globals.players[1].ID)
		
		Globals.players[0].ID = "No ID"


func create_client(IPv4, port = default_port):
	close_connection()
	_disconnect_incoming_signals()
	get_tree().network_peer = null
	
	var peer = NetworkedMultiplayerENet.new()
	var r = peer.create_client(IPv4, port)
	
	if r == OK:
		get_tree().network_peer = peer
		my_peer_id = get_tree().get_network_unique_id()
		_connect_all()
#		players[0].ID = str(my_peer_id)
	else:
		close_connection()
		print("Connection Check Failed, closing Connection")
	
	return r


func create_server(port = default_port):
	close_connection()
	_disconnect_incoming_signals()
	get_tree().network_peer = null
	
	var peer = NetworkedMultiplayerENet.new()
	var r = peer.create_server(port)
	
	if r == OK:
		get_tree().network_peer = peer
		my_peer_id = get_tree().get_network_unique_id()
		Globals.players[0].ID = my_peer_id
		_connect_all()
#		players[0].ID = str(my_peer_id)
	else:
		close_connection()
		print("Connection Check Failed, closing Connection")
	
	return r

func single_player(port = default_port+1):
	close_connection()
	_disconnect_incoming_signals()
	get_tree().network_peer = null
	
	var peer = NetworkedMultiplayerENet.new()
	peer.refuse_new_connections = true
	var r = peer.create_server(port)
	
	if r == OK:
		get_tree().network_peer = peer
		my_peer_id = get_tree().get_network_unique_id()
		Globals.players[0].ID = my_peer_id
		_connect_all()
#		players[0].ID = str(my_peer_id)
	else:
		close_connection()
		print("Connection Check Failed, closing Connection")
	
	return r

func is_server():
	return is_network_connected() and get_tree().is_network_server()

func is_network_connected():
	return get_tree().network_peer != null and get_tree().network_peer.get_connection_status() != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED

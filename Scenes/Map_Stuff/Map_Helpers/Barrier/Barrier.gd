extends StaticBody

export (String) var Product_Name = "Remove Barrier"
export (int) var Price = 750


export (Globals.Product_Types) var Product_Type = Globals.Product_Types.barrier
export (String) var Product_ID = "Barrier"


func _ready():
	if not is_in_group(Globals.GROUP_BUYABLE):
		add_to_group(Globals.GROUP_BUYABLE)
	
	if Globals.network_is_server():
		Globals.connect("send_client_map_setup_info",self,"_send_client_map_setup_info")


func interact(spatial_from: Spatial):
	rpc("set_vis", !visible)


remotesync func set_vis(b: bool):
	visible = b
	$CollisionShape.disabled = !b

func _send_client_map_setup_info(id):
	rpc_id(id,"set_vis",visible)

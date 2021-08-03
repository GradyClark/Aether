extends StaticBody


export (String) var Product_Name
export (int) var Price

export (Globals.Product_Types) var Product_Type = Globals.Product_Types.perk
export (String) var Product_ID


func _ready():
	if not is_in_group(Globals.GROUP_BUYABLE):
		add_to_group(Globals.GROUP_BUYABLE)
	
	# For some reason, you need these two lines, even though you shouldn't need them
	self.set_collision_layer_bit(3,true)
	self.set_collision_mask_bit(3,true)

remotesync func interact(spatial_from: Spatial):
	pass

extends StaticBody

export (String) var Product_Name = "Handgun"
export (int) var Price = 100
export (int) var Price_Ammo = 100
export (int) var Ammo_Amount = 0

export (Globals.Product_Types) var Product_Type
export (String) var Product_ID

remotesync func interact(spatial_from: Spatial):
	pass

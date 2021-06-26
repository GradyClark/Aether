extends Spatial

export (Array,Material) var materials

func set_visibility(b:bool):
	self.visible = b
	$"2D".visible = b
	$"3D".visible = b
	

func _ready():
	self.set_visibility(true)
	
	var type_spatial_mat = SpatialMaterial.new().get_class()
	var type_parti_mat = ParticlesMaterial.new().get_class()
	var type_canvas_mat = CanvasItemMaterial.new().get_class()
	var type_shader_mat = ShaderMaterial.new().get_class()
	
	for i in range(0,materials.size()):
		var m = materials[i]
		# Warning, "m" could by several different types of materials
		if m != null:
			var mc = m.get_class()
			if mc == type_spatial_mat:
				var mi = $"3D/shader_fix_base".duplicate(8)
				mi.material_override = m
				$"3D".add_child(mi)
			elif mc == type_parti_mat:
				var e = $"3D/particles_fix_base".duplicate(8)
				e.process_material = m
				$"3D".add_child(e)
				e.emitting = true
			elif mc == type_canvas_mat or mc == type_shader_mat:
				var c = $"2D/canvas_fix_base".duplicate(8)
				c.material = m
				$"2D".add_child(c)
	
	$Timer.start()

func _on_Timer_timeout():
	self.set_visibility(false)

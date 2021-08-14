extends Control

onready var Licenses = [
	License.new("Lexend Font License", "res://Assets/Fonts/Lexend_license.txt")
]


# Called when the node enters the scene tree for the first time.
func _ready():
	$Control/license_list.clear()
	for l in Licenses:
		$Control/license_list.add_item(l.Name)
	
	$btn_back.grab_focus()


func _on_btn_back_pressed():
	Globals.change_scene("res://Scenes/User_Interface/Menus/main_menu/main_menu.tscn")


class License:
	var Name: String
	var Text: String
	var Location: String
	
	func _init(name:String, location:String):
		Name = name
		Location = location
		Text = Globals.load_text_file(Location)


func _on_license_list_item_selected(index):
	$Control/license_text.text = Licenses[index].Text


func _on_license_text_gui_input(event):
	if event is InputEventJoypadMotion:
		if event.get_action_strength("look_down") > 0.2:
			$Control/license_text.scroll_vertical = $Control/license_text.scroll_vertical + event.get_action_strength("look_down") * 1.5
		elif event.get_action_strength("look_up") > 0.2:
			$Control/license_text.scroll_vertical = $Control/license_text.scroll_vertical - event.get_action_strength("look_up") * 2

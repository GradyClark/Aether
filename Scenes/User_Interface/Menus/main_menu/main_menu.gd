extends Node2D

func _ready():
	$lbl_version_number.text = ProjectSettings.get_setting("application/config/version")
	$btn_start.grab_focus()
	
	$te_changelog.text = Globals.load_text_file("res://changelog.txt")

func _on_btn_exit_pressed():
	Globals.quit()


func _on_btn_start_pressed():
	Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")


func _on_btn_gto_license_menu_pressed():
	Globals.change_scene("res://Scenes/User_Interface/Menus/License_Menu/License_Menu.tscn")


func _on_HTTPRequest_request_completed(result, response_code, headers, body):
	if result == HTTPRequest.RESULT_SUCCESS:
		var j:JSONParseResult = JSON.parse(body.get_string_from_utf8())
		var releases:Array = j.result
		var latest: Dictionary = releases[0]
	
		var my_version:String = ProjectSettings.get_setting("application/config/version")
	
		if latest.tag_name == my_version:
			Dialog.display("Checking for Updates", "You are running the latest version")
		else:
			Dialog.display("Checking for Updates", "You are running a different version\nLatest version is\n"+latest.tag_name+"\nLoading webpage now")
			yield(get_tree().create_timer(0.3),"timeout")
			OS.shell_open(latest.html_url)


func _on_btn_check_for_updates_pressed():
	Dialog.display("Checking for Updates", "Please Wait")
	yield(get_tree().create_timer(0.3),"timeout")
	$HTTPRequest.request("https://api.github.com/repos/gradyclark/aether/releases")


func _on_te_changelog_gui_input(event):
	if event is InputEventJoypadMotion:
		if event.get_action_strength("look_down") > 0.2:
			$te_changelog.scroll_vertical = $te_changelog.scroll_vertical + event.get_action_strength("look_down") * 1.5
		elif event.get_action_strength("look_up") > 0.2:
			$te_changelog.scroll_vertical = $te_changelog.scroll_vertical - event.get_action_strength("look_up") * 2

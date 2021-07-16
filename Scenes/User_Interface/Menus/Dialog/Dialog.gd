extends Popup

func _on_btn_ok_pressed():
	hide()

func set_text_body(text: String):
	$rtl_body.text = text
	
func set_text_title(text: String):
	$rtl_title.text = text

remotesync func display(title: String, body: String):
	set_text_title(title)
	set_text_body(body)
	popup()


func _on_tr_background_pressed():
	hide()

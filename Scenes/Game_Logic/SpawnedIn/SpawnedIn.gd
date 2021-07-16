extends Node

func _ready():
	Globals.node_spawnedin = self
	Globals.node_spawnedin_synced = $Synced
	Globals.node_spawnedin_unsynced = $Unsynced

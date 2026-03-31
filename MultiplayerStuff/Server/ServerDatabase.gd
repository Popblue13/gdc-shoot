extends Node
#and manager ;)
#if i wanted permanent stuff, look into just a simple cfg file for the future

#region DataBase

signal server_maps_updated #TODO
signal lobbies_updated 

var Players : Dictionary [int, Dictionary] 
var Maps : Dictionary [String, PackedScene] = {} #DNS (does not sync atm)
var Mercs : Dictionary [String, PackedScene] = {} #DNS
var Characters : Dictionary [String, PackedScene] = {} #DNS
var lobbies : Dictionary[String, Array] = {} #lobbyid = [player_id, ...]

#var chat 
#endregion

#region PRESET DATABASE
var PRESETMAPS : Dictionary [String, PackedScene] = {
	"lobby" = load("res://MapsAndGamemodes/Maps/Lobby/sb_lobby.tscn")
	
}

var PRESETMERCS : Dictionary [String, PackedScene] = {
	"default" = load("res://PlayerControllers/Default/FirstPersonController.tscn")
}
#endregion

#region Manager
func add_player(peer_id : int): 
	Players[peer_id] = {}
	rpc("sync_players", Players)
func remove_player(peer_id : int):
	Players.erase(peer_id)
	rpc("sync_players", Players)
@rpc("authority","call_remote","reliable")
func sync_players(_players):
	Players = _players

func update_lobbies(_lobbies):
	lobbies = _lobbies
	rpc("sync_lobbies", lobbies)
# "authority" means ONLY the server is allowed to trigger this on clients
@rpc("authority","call_remote","reliable")
func sync_lobbies(_lobbies):
	lobbies = _lobbies
	lobbies_updated.emit()

#endregion

func _ready() -> void:
	Maps = PRESETMAPS
	Mercs = PRESETMERCS

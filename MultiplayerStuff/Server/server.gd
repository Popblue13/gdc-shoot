extends Node
class_name ServerLogic

var lobby_container : LobbyContainer = null
var console_thread : Thread
func _ready() -> void:
	name = "NetworkConnection"
	
	var args = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--port" and i + 1 < args.size():
			ServerDatabase.port = args[i+1].to_int()
	
	rehost_server(ServerDatabase.port)
	
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	
	console_thread = Thread.new()
	console_thread.start(_listen_to_console)

func _listen_to_console():
	while true:
		var input = OS.read_string_from_stdin().strip_edges()
		
		# --- NEW IP COMMAND ---
		if input == "ip":
			var addresses = IP.get_local_addresses()
			print("--- Available Server IPs ---")
			for ip in addresses:
				# Filter for IPv4 and ignore internal loopback
				if "." in ip and not ip.begins_with("127."):
					print(" > ", ip)
			print("---------------------------")

		# --- REHOST COMMAND (Fixed index) ---
		elif input.begins_with("rehost"):
			var parts = input.split(" ")
			if parts.size() == 2:
				# Fixed: parts[1] is the port if input is "rehost 8080"
				var new_port = parts[1].to_int() 
				call_deferred("rehost_server", new_port)
			else:
				print("Invalid command. Use: rehost <port>")
		
		# --- HELP COMMAND ---
		elif input == "help":
			print("Commands: ip, rehost <port>, exit")

func _on_client_connected(peer_id : int):
	print(' :} client connected with id ', str(peer_id))
	ServerDatabase.add_player(peer_id)

func _on_client_disconnected(peer_id : int):
	print('>:( client disconnced with id ', str(peer_id))
	ServerDatabase.remove_player(peer_id)


func rehost_server(new_port: int) -> void:
	print("Shutting down current server...")
	
	# 1. Disconnect current peer to kick everyone cleanly
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	
	# 2. Update Database
	ServerDatabase.port = new_port
	
	# 3. Create the new server
	var peer = ENetMultiplayerPeer.new()
	# Note: ENet doesn't strictly bind to an IP when hosting unless you specify it in bind_ip
	# peer.bind_ip = ServerDatabase.address 
	var error = peer.create_server(ServerDatabase.port)
	
	if error == OK:
		multiplayer.multiplayer_peer = peer
		print("Successfully re-hosted on Port: ", ServerDatabase.port)
		lobby_container.create_new_lobby('home', [])
	else:
		print("Failed to re-host. Error: ", error)

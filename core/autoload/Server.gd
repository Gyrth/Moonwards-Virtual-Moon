extends Node

#global signals
signal server_log(msg)
# network user related
signal user_join #emit when user is fully registered
signal user_leave #emit on leave of registered user
signal user_name_disconnected(name) #emit when user is joined, for chat
signal user_name_connected(name) #emit when user is disconnected, for chat
signal user_msg(id, msg) #emit message of id user
signal player_id(id) #emit id of player after establishing a connection
#network server
signal server_up
#network general
signal network_error(message)
signal network_log(message) #emmit on change in server status, client status - conenction, establishing connection etc

# Default game port
const DEFAULT_PORT : int = 10567

# Max number of players
const MAX_PEERS : int = 12

# remote players in id:player_data format
var players : Dictionary = {}
var network_id : int 
var local_id : int = 0

# hold last error message
var error_msg : String = "Ok"

var server : Dictionary = {
	host = "localhost",
	ip = "127.0.0.1",
	connection = null,
	up = false
}

var NetworkUP : bool = false
#signal player(node_path) #emit when local player instanced to scene
#################
# util functions

var level_loader : Object = preload("res://scripts/LevelLoader.gd").new()
var world : Node = null
var debug_id : String = "server"

func _ready():
	self.connect("network_log", self, "_on_network_log")
	self.connect("server_log", self, "_on_server_log")
	self.connect("server_up", self, "_on_net_server_up")
	server_set_mode()

#################
#Server functions

func server_set_mode(host : String = "localhost"):
	server.host = host
	server.ip = IP.resolve_hostname(host, 1) #TYPE_IPV4 - ipv4 adresses only
	if not server.ip.is_valid_ip_address():
		var msg = "fail to resolve host(%s) to ip adress" % server.host
		emit_signal("network_log", msg)
		emit_signal("network_error", msg)
		return
	emit_signal("network_log", "prepare to listen on %s:%s" % [server.ip,DEFAULT_PORT])
	server.connection = NetworkedMultiplayerENet.new()
	server.connection.set_bind_ip(server.ip)
	var error : int = server.connection.create_server(DEFAULT_PORT, MAX_PEERS)
	if error == 0:
		get_tree().set_network_peer(server.connection)
		emit_signal("network_log", "server up on %s:%s" % [server.ip,DEFAULT_PORT])
		server.up = true
		emit_signal("server_up")
		
		server.connection.connect("peer_disconnected", self, "_on_server_user_disconnected")
		server.connection.connect("peer_connected", self, "_on_server_user_connected")
		
		get_tree().connect("network_peer_connected", self, "_on_server_tree_user_connected")
		get_tree().connect("network_peer_disconnected", self, "_on_server_tree_user_disconnected")

		emit_signal("server_log", "network server id %s" % server.connection.get_unique_id())
		network_id = server.connection.get_unique_id()
		emit_signal("player_id", network_id)
	else:
		emit_signal("network_log", "server error %s" % error)
		emit_signal("network_error", "failed to bring server up, error %s" % error)

################
# Player functions
func player_apply_opt(pdata : Dictionary, player : Spatial, id : int):
	#apply options, given in register dictionary under ::options
	if pdata.has("options"):
		printd("player_apply_opt to %s with %s" % [id, pdata])
		var opt = pdata.options
		printd("create_player Apply options to id %s : %s" % [id, opt])
		for k in opt:
			player.set(k, opt[k])
		if opt.has("input_processing") and opt["input_processing"] == false:
			printd("disable input for player avatar %s" % id)
			player.set_process_input(false)

func player_register(pdata : Dictionary, localplayer : bool = false, opt_id : String = "avatar") -> void:
	var id : int = 0
	if localplayer:
		pdata["options"] = options.player_opt(opt_id, pdata) #merge name with rest of options for Avatar
		if network_id:
			id = network_id
		else:
			id = local_id
	elif pdata.has("id"):
		id = pdata.id
	else:
		emit_signal("server_log", "player data should have id or be a local")
		return
	
	emit_signal("server_log", "registered player(%s): %s" % [id, pdata])
	var player = {}
	player["data"] = pdata
	player["obj"] = options.player_scene.instance()
	player_apply_opt(player["data"], player["obj"], id)
# 	player["localplayer"] = localplayer
	if localplayer:
		if network_id :
			player["id"] = id
		players[id] = player
	else:
		player["id"] = id
		players[id] = player
	

#local player recieved network id

remote func register_client(id : int, pdata : Dictionary) -> void:
	printd("remote register_client, local_id(%s): %s %s" % [local_id, id, pdata])
	if id == local_id:
		printd("Local player, skipp")
		return
	if players.has(id):
		printd("register client(%s): already exists(%s)" % [local_id, id])
		return
	printd("register_client: id(%s), data: %s" % [id, pdata])
	pdata["id"] = id
	if pdata.has("options"):
		pdata["options"] = options.player_opt("puppet", pdata["options"])
	else:
		pdata["options"] = options.player_opt("puppet")

	player_register(pdata)
	#sync existing players
	rpc("register_client", id, pdata)
	for p in players:
		printd("**** %s" % players[p])
		var pid = players[p].id
		if pid != id:
			rpc_id(id, "register_client", pid, players[p].data)

remote func unregister_client(id : int) -> void:
	emit_signal("server_log", "unregister client (%s)" % id)
	if players.has(id):
		if players[id].obj:
			players[id].obj.queue_free()
		players.erase(id)
	#sync existing players
	for p in players:
		print("**** %s" % players[p])
		var pid = players[p].id
		if pid != local_id:
			rpc_id(pid, "unregister_client", id)

#remap local user for its network id, when he gets it
func player_remap_id(old_id : int, new_id : int) -> void:
	if players.has(old_id):
		var player = players[old_id]
		players.erase(old_id)
		players[new_id] = player
		player["id"] = new_id
		emit_signal("server_log", "remap player old_id(%s), new_id(%s)" % [old_id, new_id])
		if player.has("path"):
			var node = player.obj
			node.name = "%s" % new_id
			var world = get_tree().current_scene
			emit_signal("server_log", "remap player, old path %s to %s" % [player.path, world.get_path_to(node)])
			player["path"] = world.get_path_to(node)
			node.set_network_master(new_id)

func create_player(id : int) -> void:
	var world = get_tree().current_scene
	if players[id].has("world") and players[id]["world"] == str(world):
		emit_signal("server_log", "player(%s) already added, %s" % [id, players[id]])
		return
	var spawn_pcount =  world.get_node("spawn_points").get_child_count()
	var spawn_pos = randi() % spawn_pcount
	emit_signal("server_log", "select spawn point(%s/%s)" % [spawn_pos, spawn_pcount])
	spawn_pos = world.get_node("spawn_points").get_child(spawn_pos).translation
	var player = players[id].obj
#	player.flies = true # MUST CHANGE WHEN COLLISIONS ARE DONE
	player.set_name(str(id)) # Use unique ID as node name
	player.translation=spawn_pos
	
	if players[id].data.has("network"):
		player.nonetwork = !players[id].data.network
	
	printd("cp set_network will set(%s) %s %s" % [players[id].has("id") and not player.nonetwork, players[id].has("id"), not player.nonetwork])
	if players[id].has("id") and not player.nonetwork:
		printd("create player set_network_master player id(%s) network id(%s)" % [id, players[id].id])
		player.set_network_master(players[id].id) #set unique id as master
	
	emit_signal("server_log", "==create player(%s) %s; name(%s)" % [id, players[id], players[id].data.username])
	world.get_node("players").add_child(player)
	players[id]["world"] = "%s" % world
	players[id]["path"] = world.get_path_to(player)

#set current camera to local player
func player_local_camera(activate : bool = true) -> void:
	if players.has(local_id):
		players[local_id].obj.nocamera = !activate

func player_noinput(enable : bool = false) -> void:
	if players.has(local_id):
		players[local_id].obj.input_processing = enable

# Callback from SceneTree, only for clients (not server)

# Lobby management functions

func end_game() -> void:
	if (has_node("/root/world")): # Game is in progress
		# End it
		get_node("/root/world").queue_free()

	emit_signal("game_ended")
	players.clear()
	get_tree().set_network_peer(null) # End networking

#################
# debug functions


func printd(s : String) -> void:
	logg.print_filtered_message(debug_id, s)

#################
# New UI functions



func loading_done(var error : int) -> void:
	if error == OK or error == ERR_FILE_EOF:
		emit_signal("server_log", "changing scene okay(%s)" % level_loader.error)
		emit_signal("loading_done")
	else:
		emit_signal("server_log", "error changing scene %s" % level_loader.error)
		emit_signal("loading_error", "Error! " + str(error))

func load_level(var resource) -> void: #Resource is variant
	# Check if the resource is valid before switching to loading screen.
	if resource is String:
		if options.scenes.has(resource):
			resource = options.scenes[resource].path
		if not ResourceLoader.exists(resource):
			emit_signal("loading_error", "File does not exist: " + resource)
			return
	elif resource is PackedScene:
		if not resource.can_instance():
			emit_signal("loading_error", "Can not instance resource.")
			return
	
	level_loader.start_loading(resource)
	yield(self, "loading_done")
	
	world = level_loader.new_scene.instance()
	get_tree().get_root().add_child(world)
	get_tree().current_scene = world
	emit_signal("scene_change")

#################
# avatar network/scene functions

#network and player scene state


func net_up() -> void: 
	printd("------net_up---enable networking in instanced players--------")

func net_down() -> void:
	printd("------net_down---players disable netwokring--------")

func net_client(id : int, connected : bool) -> void:
	if connected:
		printd("------net_client(%s)---make stub for %s---------" % [connected, id])
	else:
		printd("------net_client(%s)---disconnect client %s-----" % [connected, id])

func player_scene() -> void:
	printd("------instance avatars with networking(%s) - players count %s" % [NetworkUP, players.size()])

func _on_net_connection_fail() -> void:
	printd("***********net_connection_fail")
	NetworkUP = false

func _on_net_client_connected(id : int) -> void:
	printd("***********net_client_connected(%s)" % id)
	net_client(id, true)

func _on_net_client_disconnected(id : int) -> void:
	printd("***********net_client_disconnected(%s)" % id)
	net_client(id, false)

func _on_net_server_connected() -> void:
	printd("***********net_server_connected")
	if not NetworkUP:
		NetworkUP = true
		net_up()

func _on_net_server_disconnected() -> void:
	printd("***********net_server_disconnected")
	if NetworkUP:
		NetworkUP = false
		net_down()

func _on_net_server_up() -> void:
	printd("***********net_server_up")
	if not NetworkUP:
		NetworkUP = true
		net_up()

func _on_server_user_connected(id : int) -> void:
	emit_signal("server_log", "user connected %s" % id)

func _on_server_user_disconnected(id : int) -> void:
	emit_signal("server_log", "user disconnected %s" % id)

func _on_server_tree_user_connected(id : int) -> void:
	emit_signal("server_log", "tree user connected %s" % id)

func _on_server_tree_user_disconnected(id : int) -> void:
	emit_signal("server_log", "tree user disconnected %s" % id)
	unregister_client(id)


func _on_player_scene() -> void:
	emit_signal("server_log", "scene is player ready, checking players(%s)" % players.size())
	if options.debug:
		for p in players:
			emit_signal("server_log", "player %s" % players[p])
	for p in players:
		create_player(p)

func _on_player_id(id : int) -> void:
	if not players.has(local_id):
		return
	player_remap_id(local_id, id)
	local_id = id
	#scene is not active yet, payers are redistered after scene is changes sucessefully

func _server_disconnected() -> void:
	emit_signal("game_error", "Server disconnected")
	end_game()

# Callback from SceneTree, only for clients (not server)
func _connected_fail() -> void:
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

func _on_connection_failed() -> void:
	emit_signal("server_log", "client connection failed to %s(%s):%s" % [player_get("host"), player_get("ip"), player_get("port")])
	emit_signal("network_error", "Error connecting to server %s(%s):%s" % [player_get("host"), player_get("ip"), player_get("port")])

func _on_connected_to_server() -> void:
	emit_signal("server_log", "client connected to %s(%s):%s" % [player_get("host"), player_get("ip"), player_get("port")])
	emit_signal("server_connected")

func _on_network_log(msg) -> void:
	printd("Server log: %s" % msg)

func _on_server_log(msg) -> void:
	printd("server log: %s" % msg)

func _on_scene_change_log() -> void:
	printd("===gs on_scene_change")
	printd("get_tree: %s" % get_tree())
	if get_tree():
		if get_tree().current_scene :
			printd("current scene: %s" % get_tree().current_scene)

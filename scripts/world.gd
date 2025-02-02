extends Node

@onready var main_menu: PanelContainer = $Menu/MainMenu
@onready var options_menu: PanelContainer = $Menu/Options
@onready var pause_menu: PanelContainer = $Menu/PauseMenu
@onready var address_entry: LineEdit = %AddressEntry
@onready var menu_music: AudioStreamPlayer = %MenuMusic
@onready var match_timer: Timer = $MatchTimer  # Timer node
@onready var timer_label: Label = $MatchTimerLabel  # Timer label node

const Player = preload("res://player.tscn")
const PORT = 9999
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false

func _ready():
	# Set the match timer properties
	match_timer.wait_time = 180  # 2 minutes match duration (static number)
	match_timer.one_shot = true  # Timer will run only once

	# Start the timer
	match_timer.start()

	# Connect the timeout signal to the handler function
	match_timer.timeout.connect(_on_match_timer_timeout)

	# Center the timer label on the screen (using static values for screen size and label size)
	var screen_width = 1280  # Static screen width (replace with your desired number)
	var screen_height = 720  # Static screen height (replace with your desired number)
	var label_width = 200    # Static label width (replace with your desired number)
	var label_height = 50    # Static label height (replace with your desired number)

	# Calculate the position of the label
	var label_position = Vector2((screen_width - label_width) / 2, 0)
	timer_label.position = label_position



func _process(_delta: float) -> void:
	if paused:
		$Menu/Blur.show()
		pause_menu.show()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	update_timer_label()  # Keep updating the timer display

func update_timer_label():
	if timer_label:  # Check if timer_label is not null
		var time_left = int(match_timer.time_left)
		var minutes = time_left / 60
		var seconds = time_left % 60
		timer_label.text = "Time Left: %02d:%02d" % [minutes, seconds]
	else:
		print("timer_label is null!")

func _on_match_timer_timeout():
	timer_label.text = "Match Over!"
	end_match()

func end_match():
	print("Match has ended!")
	
	# Freeze gameplay
	get_tree().paused = true
	
	# Play the menu music
	menu_music.play()
	
	# Reposition the timer label to center-center
	var screen_size = get_viewport().get_visible_rect().size
	var label_size = timer_label.get_minimum_size()
	timer_label.position = (screen_size - label_size) / 2

# Handling pause input
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and !main_menu.visible and !options_menu.visible:
		paused = !paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false

func _on_resume_pressed() -> void:
	if !options:
		$Menu/Blur.hide()
	$Menu/PauseMenu.hide()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = false

func _on_options_pressed() -> void:
	_on_resume_pressed()
	$Menu/Options.show()
	$Menu/Blur.show()
	%Fullscreen.grab_focus()
	if not controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if not controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

# Hosting the game (server side)
func _on_host_button_pressed() -> void:
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()

	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	if options_menu.visible:
		options_menu.hide()

	add_player(multiplayer.get_unique_id())

	print("Hosting game on port %d. Players can connect using your IP address." % PORT)

# Joining the game (client side)
func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()

	var host_address: String = address_entry.text
	if host_address == "":
		print("Please enter the host address.")
		return

	enet_peer.create_client(host_address, PORT)
	if options_menu.visible:
		options_menu.hide()

	multiplayer.multiplayer_peer = enet_peer

func _on_options_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		options_menu.show()
	else:
		options_menu.hide()

func _on_music_toggle_toggled(toggled_on: bool) -> void:
	if !toggled_on:
		menu_music.stop()
	else:
		menu_music.play()

# Adding and removing players
func add_player(peer_id: int) -> void:
	var player: Node = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

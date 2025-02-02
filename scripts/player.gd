extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash: GPUParticles3D = $Camera3D/pistol/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound

## Weapons
@onready var gun1 = $Camera3D/pistol/Gun1
@onready var gun2 = $Camera3D/pistol/Gun2
@onready var gun3 = $Camera3D/pistol

## Character positions
@onready var holding_gun : Node3D = $Camera3D/pistol/HoldingHandGunStickman
@onready var shooting_gun : Node3D = $Camera3D/pistol/ShootHandGunStickman
@onready var return_timer: Timer = Timer.new()  # Create a new Timer node dynamically

## UI Labels
@onready var ui_label: Label = $DeathKillLabel  # Ensure you have a CanvasLayer with a Label named "DeathKillLabel"

var current_weapon = 1  # Default to Gun1
var sensitivity: float = 0.005
var controller_sensitivity: float = 0.010

const SPEED = 5.5
const JUMP_VELOCITY = 4.5

## Health and Respawn
@export var health: int = 2
@export var spawns: PackedVector3Array = [
	Vector3(-18, 0.2, 0),
	Vector3(18, 0.2, 0),
	Vector3(-2.8, 0.2, -6),
	Vector3(-17, 0, 17),
	Vector3(17, 0, 17),
	Vector3(17, 0, -17),
	Vector3(-17, 0, -17)
]

var axis_vector: Vector2
var mouse_captured: bool = true

var death_count: int = 0  # Tracks player deaths
var kill_count: int = 0   # Tracks player kills
	
func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if not is_multiplayer_authority(): return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	position = spawns[randi() % spawns.size()]
	switch_weapon(current_weapon)  # Initialize weapon selection
	holding_gun.visible = true
	shooting_gun.visible = false
	return_timer.wait_time = 3.0  # 3 seconds delay
	return_timer.one_shot = true  # Only triggers once per activation
	return_timer.timeout.connect(switch_to_hold_position)  # Call function on timeout
	add_child(return_timer)  # Add the timer to the scene
	
	if ui_label:
		ui_label.anchor_right = 1.0
		ui_label.anchor_left = 1.0
		ui_label.anchor_top = 0.0
		ui_label.anchor_bottom = 0.0
		ui_label.position = Vector2(1000, 0)
	update_ui()  # Update UI at start

func _process(_delta: float) -> void:
	sensitivity = Global.sensitivity
	controller_sensitivity = Global.controller_sensitivity

	rotate_y(-axis_vector.x * controller_sensitivity)
	camera.rotate_x(-axis_vector.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return

	axis_vector = Input.get_vector("look_left", "look_right", "look_up", "look_down")

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI / 2, PI / 2)

	# Weapon switching using number keys
	if Input.is_action_just_pressed("gun1"):
		switch_weapon(1)
	elif Input.is_action_just_pressed("gun2"):
		switch_weapon(2)
	elif Input.is_action_just_pressed("gun3"):
		switch_weapon(3)

	# Weapon switching using scroll wheel
func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_weapon = (current_weapon % 3) + 1  # Cycle 1 → 2 → 3 → 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_weapon = 3 if current_weapon == 1 else current_weapon - 1  # Cycle 3 → 2 → 1 → 3
		
		switch_weapon(current_weapon)

	if Input.is_action_just_pressed("shoot"):
		switch_to_shoot_position()
		gunshot_sound.play()
		play_shoot_effects.rpc()
		if raycast.is_colliding() and str(raycast.get_collider()).contains("CharacterBody3D"):
			var hit_player: Object = raycast.get_collider()
			hit_player.recieve_damage.rpc_id(hit_player.get_multiplayer_authority())
		# Restart the timer every time we shoot (delays returning to hold position)
		return_timer.start()
	if Input.is_action_just_pressed("respawn"):
		recieve_damage(2)

	if Input.is_action_just_pressed("capture"):
		mouse_captured = not mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects() -> void:
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func recieve_damage(damage: int = 1, attacker_id: int = -1) -> void:
	health -= damage
	if health <= 0:
		death_count += 1  # Increment death count
		health = 4
		position = spawns[randi() % spawns.size()]

		# Automatically switch weapons after death
		current_weapon = (current_weapon % 2) + 1  # Cycles between Gun1 and Gun2
		switch_weapon(current_weapon)

		print("You died! Respawning...")
		print("Death count:", death_count)  # Display death count

		update_ui()  # Update the UI when player dies

		# If the attacker_id is valid, notify them of the kill
		if attacker_id != -1 and attacker_id != get_multiplayer_authority():
			rpc_id(attacker_id, "register_kill")

@rpc("any_peer")
func register_kill() -> void:
	kill_count += 1  # Increment kill count
	print("You killed an enemy! Total kills:", kill_count)

	update_ui()  # Update the UI when player gets a kill
	
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "shoot":
		anim_player.play("idle")

func switch_weapon(weapon_id: int) -> void:
	"""
	Switches between the available weapons.
	"""
	current_weapon = weapon_id
	gun1.visible = weapon_id == 1
	gun2.visible = weapon_id == 2

	# Play equip animation (if any)
	anim_player.play("equip") if anim_player.has_animation("equip") else null

	print("Switched to weapon:", current_weapon)

func switch_to_shoot_position():
	if holding_gun and shooting_gun :
		holding_gun.visible = false
		shooting_gun.visible = true

func switch_to_hold_position():
	if holding_gun and shooting_gun :
		holding_gun.visible = true
		shooting_gun.visible = false


func update_ui() -> void:
	if ui_label:
		ui_label.text = "Deaths: %d | Kills: %d" % [death_count, kill_count]

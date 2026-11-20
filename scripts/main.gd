extends Node3D

# Original playable Open City 3D prototype.
const SPEED := 6.5
const CAR_SPEED := 17.0
var hero: CharacterBody3D
var car: CharacterBody3D
var camera: Camera3D
var in_car := false
var steer := Vector2.ZERO
var jump_requested := false
var interact_requested := false
var car_heading := 0.0
var hud: Label
var camera_yaw := 0.0
var camera_pitch := 0.30
var camera_distance := 10.0
var look_touch_id := -1
var touch_last := Vector2.ZERO
var car_velocity := 0.0

func _ready() -> void:
	_build_world()
	_build_player()
	_build_car()
	_build_ui()

func _box(parent: Node3D, pos: Vector3, size: Vector3, tint: Color, collision := true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	parent.add_child(body)
	body.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mesh.material_override = mat
	body.add_child(mesh)
	if collision:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		col.shape = box
		body.add_child(col)
	return body

func _build_world() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.5
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.75, 0.94)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.85, 0.95)
	env.environment = e
	add_child(env)
	_box(self, Vector3(0,-0.6,0), Vector3(240,1,240), Color(0.23,0.45,0.27))
	for i in range(-2,3):
		_box(self,Vector3(i*35,0.01,0),Vector3(13,0.12,220),Color(0.18,0.19,0.22),false)
		_box(self,Vector3(0,0.02,i*35),Vector3(220,0.12,13),Color(0.18,0.19,0.22),false)
	for i in range(-3,4):
		for j in range(-3,4):
			if abs(i) < 1 and abs(j) < 1: continue
			var px := i*25.0+12.0
			var pz := j*25.0+12.0
			if fmod(abs(px),35.0)<8.0 or fmod(abs(pz),35.0)<8.0: continue
			var height := 7.0+float(posmod(i*13+j*7,7))*2.7
			_box(self,Vector3(px,height/2,pz),Vector3(12,height,12),Color(0.45+0.04*float(posmod(i,3)),0.45,0.50))
			for floor_i in range(1,int(height/3.0)):
				_box(self,Vector3(px,floor_i*3.0,pz-6.03),Vector3(8,1.1,0.06),Color(0.15,0.33,0.46),false)

func _build_player() -> void:
	hero = CharacterBody3D.new()
	hero.position = Vector3(0,1,9)
	add_child(hero)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	hero.add_child(shape)
	var mesh := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.8
	mesh.mesh = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16,0.36,0.9)
	mesh.material_override = mat
	hero.add_child(mesh)
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

func _build_car() -> void:
	car = CharacterBody3D.new()
	car.position = Vector3(4,0.9,9)
	add_child(car)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2,1.4,4)
	shape.shape = box
	car.add_child(shape)
	_box(car,Vector3.ZERO,Vector3(2,1.1,4),Color(0.85,0.16,0.12),false)
	_box(car,Vector3(0,0.85,-0.2),Vector3(1.7,0.7,1.9),Color(0.15,0.25,0.33),false)
	for side in [-1,1]:
		for z in [-1.25,1.25]:
			_box(car,Vector3(side*1.02,-0.35,z),Vector3(0.2,0.7,0.8),Color(0.07,0.07,0.08),false)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.text = "OPEN CITY 3D  |  WALK / DRIVE  |  E: ENTER / EXIT"
	hud.position = Vector2(24,20)
	hud.add_theme_font_size_override("font_size",25)
	layer.add_child(hud)
	var controls := [
		["◀",Vector2(40,570),Vector2(-1,0),"move"],
		["▶",Vector2(160,570),Vector2(1,0),"move"],
		["▲",Vector2(100,475),Vector2(0,-1),"move"],
		["▼",Vector2(100,650),Vector2(0,1),"move"],
		["JUMP",Vector2(980,590),Vector2.ZERO,"jump"],
		["ENTER / EXIT",Vector2(1030,480),Vector2.ZERO,"interact"]]
	for item in controls:
		var b := Button.new()
		b.text = item[0]
		b.position = item[1]
		b.custom_minimum_size = Vector2(110,65)
		b.add_theme_font_size_override("font_size",21)
		layer.add_child(b)
		if item[3] == "move":
			b.button_down.connect(_press_move.bind(item[2]))
			b.button_up.connect(_release_move.bind(item[2]))
		elif item[3] == "jump":
			b.pressed.connect(func(): jump_requested = true)
		else:
			b.pressed.connect(func(): interact_requested = true)

func _press_move(direction: Vector2) -> void:
	steer += direction

func _release_move(direction: Vector2) -> void:
	steer -= direction

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
			if look_touch_id == -1:
				look_touch_id = event.index
				touch_last = event.position
		elif not event.pressed and event.index == look_touch_id:
			look_touch_id = -1
	elif event is InputEventScreenDrag and event.index == look_touch_id:
		var diff: Vector2 = event.position - touch_last
		touch_last = event.position
		camera_yaw -= diff.x * 0.006
		camera_pitch = clamp(camera_pitch + diff.y * 0.004, -0.15, 0.85)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_yaw -= event.relative.x * 0.006
		camera_pitch = clamp(camera_pitch + event.relative.y * 0.004, -0.15, 0.85)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("interact") or interact_requested:
		interact_requested = false
		if in_car:
			in_car = false
			hero.position = car.position + Vector3(2.5,0,0)
		elif hero.position.distance_to(car.position) < 5.0:
			in_car = true
	var direction := steer
	direction.x += Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y += Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	direction = direction.limit_length(1.0)
	if in_car:
		var target_speed := -direction.y * CAR_SPEED
		car_velocity = move_toward(car_velocity, target_speed, delta * (14.0 if abs(target_speed) > 0.1 else 24.0))
		var steering_factor := clamp(abs(car_velocity) / 5.0, 0.0, 1.0)
		car_heading -= direction.x * delta * 1.65 * steering_factor * (1.0 if car_velocity >= 0.0 else -1.0)
		car.rotation.y = car_heading
		var forward := Vector3(-sin(car_heading),0,-cos(car_heading))
		car.velocity = forward * car_velocity
		car.move_and_slide()
		hero.visible = false
	else:
		hero.visible = true
		var forward := Vector3(-sin(camera_yaw), 0, -cos(camera_yaw))
		var right := Vector3(cos(camera_yaw), 0, -sin(camera_yaw))
		var movement := (right * direction.x - forward * direction.y).limit_length(1.0)
		hero.velocity.x = movement.x * SPEED
		hero.velocity.z = movement.z * SPEED
		if movement.length() > 0.1:
			hero.rotation.y = lerp_angle(hero.rotation.y, atan2(-movement.x, -movement.z), delta * 10.0)
		if not hero.is_on_floor():
			hero.velocity.y -= 18.0*delta
		elif jump_requested or Input.is_action_just_pressed("ui_accept"):
			hero.velocity.y = 7.0
		hero.move_and_slide()
	jump_requested = false
	var target := car.global_position if in_car else hero.global_position
	if in_car and look_touch_id == -1:
		camera_yaw = lerp_angle(camera_yaw, car_heading, delta * 0.9)
	var horizontal := cos(camera_pitch) * camera_distance
	var offset := Vector3(sin(camera_yaw) * horizontal, 3.0 + sin(camera_pitch) * camera_distance, cos(camera_yaw) * horizontal)
	var desired := target + offset
	camera.global_position = camera.global_position.lerp(desired, min(1.0,delta*5.0))
	camera.look_at(target+Vector3(0,1.2,0))
	hud.text = "OPEN CITY 3D  |  " + ("DRIVING" if in_car else "ON FOOT") + "  |  SWIPE RIGHT TO LOOK"

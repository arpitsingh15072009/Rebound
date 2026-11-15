extends Node2D

const TILE := 32
const ROWS := 16
const PLAYER_SCENE := preload("res://player.tscn")

const LEVELS := [
	{
		"name": "First Hops",
		"rows": [
			"..P.............^..........^^.........G.",
			"###########...######...##########...####",
			"###########...######...##########...####",
		],
	},
	{
		"name": "Up We Go",
		"rows": [
			"..................................#####.........",
			"................................................",
			"................................................",
			"................................................",
			"....................^...........................",
			"..................#####.........................",
			".............................S..................",
			"..........#####............#####.............G..",
			"..P.......................................######",
			"#######...................................######",
			"#######...................................######",
		],
	},
	{
		"name": "Duck and Cover",
		"rows": [
			"..........................##########..................",
			"............#.............vvvvvvvvvv..................",
			"............#......................................G..",
			"............#..................................#######",
			"..P.........#.....^^^^^..............SS........#######",
			"#######################################........#######",
			"#######################################........#######",
		],
	},
]

var level_index := 0
var deaths := 0
var spawn_pos := Vector2.ZERO
var level_size := Vector2.ZERO
var busy := false
var finished := false
var player

@onready var level_root: Node2D = $LevelRoot
@onready var info_label: Label = $UI/InfoLabel
@onready var message_label: Label = $UI/MessageLabel

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1b1b3a"))
	message_label.visible = false
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.died.connect(_on_player_died)
	load_level(0)

func _physics_process(_delta: float) -> void:
	if player.alive and player.global_position.y > level_size.y + 100.0:
		player.die()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		if finished:
			deaths = 0
			finished = false
			hide_message()
			load_level(0)
		elif not busy:
			load_level(level_index)
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://menu.tscn")


func load_level(i: int) -> void:
	level_index = i
	for child in level_root.get_children():
		child.queue_free()

	var rows: Array = LEVELS[i]["rows"].duplicate()
	while rows.size() < ROWS:
		rows.push_front(".".repeat(rows[0].length()))
	for r in rows:
		if r.length() != rows[0].length():
			push_error("Level row has the wrong length: " + r)

	level_size = Vector2(rows[0].length(), rows.size()) * TILE
	build_solids(rows)

	for y in rows.size():
		for x in rows[y].length():
			var pos := Vector2(x, y) * TILE
			match rows[y][x]:
				"^": add_spike(pos, false)
				"v": add_spike(pos, true)
				"S": add_spring(pos)
				"G": add_goal(pos)
				"P": spawn_pos = pos + Vector2(TILE / 2.0, TILE / 2.0)

	var cam: Camera2D = player.get_node("Camera2D")
	cam.limit_left = 0
	cam.limit_right = int(level_size.x)
	cam.limit_top = 0
	cam.limit_bottom = int(level_size.y)
	player.respawn(spawn_pos)
	cam.reset_smoothing()

	busy = false
	update_labels()
	flash_message(LEVELS[i]["name"])

func build_solids(rows: Array) -> void:
	for y in rows.size():
		var x := 0
		while x < rows[y].length():
			if rows[y][x] == "#":
				var start := x
				while x < rows[y].length() and rows[y][x] == "#":
					x += 1
				add_solid(Rect2(start * TILE, y * TILE, (x - start) * TILE, TILE))
			else:
				x += 1
	add_solid(Rect2(-32, -200, 32, level_size.y + 600), false)
	add_solid(Rect2(level_size.x, -200, 32, level_size.y + 600), false)

func add_solid(rect: Rect2, visible_block := true) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	if visible_block:
		var fill := ColorRect.new()
		fill.color = Color("#3d348b")
		fill.position = -rect.size / 2.0
		fill.size = rect.size
		body.add_child(fill)
		var top := ColorRect.new()
		top.color = Color("#7678ed")
		top.position = -rect.size / 2.0
		top.size = Vector2(rect.size.x, 5)
		body.add_child(top)
	level_root.add_child(body)

func add_spike(pos: Vector2, hanging: bool) -> void:
	var area := Area2D.new()
	area.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, 10.0 if hanging else TILE - 10.0)
	area.add_child(shape)
	var tri := Polygon2D.new()
	tri.color = Color("#ff4d6d")
	if hanging:
		tri.polygon = PackedVector2Array([Vector2(2, 0), Vector2(16, 26), Vector2(30, 0)])
	else:
		tri.polygon = PackedVector2Array([Vector2(2, TILE), Vector2(16, 6), Vector2(30, TILE)])
	area.add_child(tri)
	area.body_entered.connect(_on_spike_touched.bind(area, hanging))
	level_root.add_child(area)

func add_spring(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 14)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, TILE - 7.0)
	area.add_child(shape)
	var base := ColorRect.new()
	base.color = Color("#2ec4b6")
	base.position = Vector2(2, TILE - 10)
	base.size = Vector2(28, 10)
	area.add_child(base)
	var plate := ColorRect.new()
	plate.color = Color("#cbf3f0")
	plate.position = Vector2(2, TILE - 14)
	plate.size = Vector2(28, 4)
	area.add_child(plate)
	area.body_entered.connect(_on_spring_touched)
	level_root.add_child(area)

func add_goal(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 32)
	shape.shape = rect
	shape.position = Vector2(TILE / 2.0, TILE / 2.0)
	area.add_child(shape)
	var pole := ColorRect.new()
	pole.color = Color.WHITE
	pole.position = Vector2(14, 0)
	pole.size = Vector2(4, TILE)
	area.add_child(pole)
	var flag := Polygon2D.new()
	flag.color = Color("#ffd23f")
	flag.polygon = PackedVector2Array([Vector2(18, 2), Vector2(32, 9), Vector2(18, 16)])
	area.add_child(flag)
	area.body_entered.connect(_on_goal_touched)
	level_root.add_child(area)


func _on_spike_touched(body: Node2D, spike: Area2D, hanging: bool) -> void:
	if body != player or not player.alive:
		return
	player.die()
	var pos := spike.position
	spike.queue_free()
	if not hanging:
		call_deferred("add_spring", pos)

func _on_spring_touched(body: Node2D) -> void:
	if body == player:
		player.spring()

func _on_goal_touched(body: Node2D) -> void:
	if body != player or busy:
		return
	busy = true
	player.alive = false
	show_message("LEVEL CLEAR!")
	await get_tree().create_timer(1.2).timeout
	hide_message()
	if level_index + 1 < LEVELS.size():
		load_level(level_index + 1)
	else:
		finished = true
		show_message("YOU BOUNCED BACK!\nDeaths: %d\n\nPress R to play again\nEsc for menu" % deaths)

func _on_player_died() -> void:
	deaths += 1
	update_labels()
	burst(player.global_position)
	await get_tree().create_timer(0.8).timeout
	if busy:
		return
	player.respawn(spawn_pos)
	flash_message("BOUNCE BACK!")


func update_labels() -> void:
	info_label.text = "Level %d/%d - %s     Deaths: %d" % [level_index + 1, LEVELS.size(), LEVELS[level_index]["name"], deaths]

func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true

func hide_message() -> void:
	message_label.visible = false

func flash_message(text: String) -> void:
	show_message(text)
	await get_tree().create_timer(0.7).timeout
	if not busy and not finished:
		hide_message()

func burst(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.7
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 300.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color("#ff9f1c")
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)

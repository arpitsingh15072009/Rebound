
extends CharacterBody2D

signal died
signal bounced(high_power: bool)

const GRAVITY := 1400.0
const MOVE_SPEED := 240.0
const ACCEL := 1800.0

const BOUNCE_LOW := 380.0
const BOUNCE_NORMAL := 520.0
const BOUNCE_HIGH := 720.0
const SPRING_BOUNCE := 980.0
const RADIUS := 14.0

var alive := true
var squash := 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		return

	velocity.y += GRAVITY * delta

	var dir := Input.get_axis("left", "right")
	velocity.x = move_toward(
		velocity.x,
		dir * MOVE_SPEED,
		ACCEL * delta
	)

	move_and_slide()

	if is_on_floor():
		var power := BOUNCE_NORMAL

		if Input.is_action_pressed("high"):
			power = BOUNCE_HIGH
		elif Input.is_action_pressed("low"):
			power = BOUNCE_LOW

		velocity.y = -power
		squash = 0.3

		bounced.emit(power == BOUNCE_HIGH)

	squash = move_toward(squash, 0.0, 2.5 * delta)
	queue_redraw()


func die() -> void:
	if not alive:
		return

	alive = false
	visible = false
	velocity = Vector2.ZERO

	died.emit()


func spring() -> void:
	if not alive:
		return

	velocity.y = -SPRING_BOUNCE
	squash = 0.45


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	squash = 0.0

	alive = true
	visible = true

	queue_redraw()


func _draw() -> void:
	draw_set_transform(
		Vector2(0, RADIUS * squash),
		0.0,
		Vector2(1.0 + squash, 1.0 - squash)
	)

	var look := clampf(velocity.x / MOVE_SPEED, -1.0, 1.0) * 1.5

	draw_circle(Vector2.ZERO, RADIUS, Color("#ff9f1c"))

	draw_circle(Vector2(5, -3), 3.5, Color.WHITE)
	draw_circle(Vector2(-5, -3), 3.5, Color.WHITE)

	draw_circle(Vector2(5 + look, -3), 1.6, Color("#1b1b3a"))
	draw_circle(Vector2(-5 + look, -3), 1.6, Color("#1b1b3a"))

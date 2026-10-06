extends Node2D

const GRID_WIDTH := 10
const GRID_HEIGHT := 8
const CELL_SIZE := 50

const WALLS := [
	Vector2i(3, 1),
	Vector2i(3, 2),
	Vector2i(3, 3),
	Vector2i(6, 4),
	Vector2i(7, 4),
	Vector2i(8, 4)
]

var grid := []

var robot_position := Vector2i(0, 0)
var robot_direction := Vector2i(1, 0)
var robot: ColorRect
var code_editor: TextEdit
var goal_position := Vector2i(8, 6)
var goal: ColorRect
var level_complete := false
var program_running := false
var victory_label: Label
var error_label: Label

func _ready():
	create_grid()
	create_robot()
	create_goal()

	code_editor = $UI/CodeEditor

func create_grid():
	for y in range(GRID_HEIGHT):
		var row := []

		for x in range(GRID_WIDTH):
			var cell := ColorRect.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE - 2, CELL_SIZE - 2)

			if Vector2i(x, y) in WALLS:
				cell.color = Color("#111111")
			else:
				cell.color = Color("#303030")

			$Grid.add_child(cell)
			row.append(cell)

		grid.append(row)


func create_robot():
	robot = ColorRect.new()
	robot.size = Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	robot.color = Color("#00ff88")

	$Grid.add_child(robot)

	update_robot_position()


func update_robot_position():
	robot.position = Vector2(
		robot_position.x * CELL_SIZE + 5,
		robot_position.y * CELL_SIZE + 5
	)
func move():
	if level_complete:
		return
	var next_position := robot_position + robot_direction

	if next_position.x < 0 or next_position.x >= GRID_WIDTH:
		return

	if next_position.y < 0 or next_position.y >= GRID_HEIGHT:
		return

	if next_position in WALLS:
		return

	robot_position = next_position
	update_robot_position()

	if robot_position == goal_position:
		level_complete = true
		print("LEVEL COMPLETE!")
		show_victory()
func _input(event):
	if event.is_action_pressed("ui_right"):
		execute_command("move")

	if event.is_action_pressed("ui_up"):
		turn_right()

	if event.is_action_pressed("ui_down"):
		turn_left()

func turn_right():
	robot_direction = Vector2i(-robot_direction.y, robot_direction.x)
func turn_left():
	robot_direction = Vector2i(robot_direction.y, -robot_direction.x)
func create_goal():
	goal = ColorRect.new()
	goal.size = Vector2(CELL_SIZE - 10, CELL_SIZE - 10)
	goal.color = Color("#ffd700")

	$Grid.add_child(goal)

	goal.position = Vector2(
		goal_position.x * CELL_SIZE + 5,
		goal_position.y * CELL_SIZE + 5
	)
func show_victory():
	victory_label = Label.new()
	victory_label.text = "LEVEL COMPLETE!"
	victory_label.position = Vector2(250, 180)
	victory_label.add_theme_font_size_override("font_size", 32)
	$Grid.add_child(victory_label)
func execute_command(command: String) -> bool:
	match command:
		"move()":
			move()
			return true
		"turn_left()":
			turn_left()
			return true
		"turn_right()":
			turn_right()
			return true
		_:
			return false
func run_program():
	if program_running:
		return

	reset_level()
	program_running = true

	await get_tree().create_timer(0.3).timeout

	var lines := code_editor.text.split("\n")
	var line_number := 0

	for line in lines:
		line_number += 1

		var command := line.strip_edges()

		if command == "":
			continue

		var valid := execute_command(command)

		if not valid:
			var message := "Line %d: Unknown command '%s'" % [line_number, command]
			print(message)
			show_error(message)
			break

		await get_tree().create_timer(0.3).timeout

	program_running = false


func _on_run_button_pressed():
	run_program()

func show_error(message: String):
	if error_label:
		error_label.queue_free()

	error_label = Label.new()
	error_label.text = message
	error_label.position = Vector2(520, 480)
	error_label.add_theme_font_size_override("font_size", 18)
	error_label.modulate = Color("#ff5555")

	$UI.add_child(error_label)
func reset_level():
	robot_position = Vector2i(0, 0)
	robot_direction = Vector2i(1, 0)
	level_complete = false

	update_robot_position()

	if victory_label:
		victory_label.queue_free()
		victory_label = null

	if error_label:
		error_label.queue_free()
		error_label = null

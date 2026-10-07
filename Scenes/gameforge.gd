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
var robot_face: Label
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
	robot_face = Label.new()
	robot_face.text = "▶"
	robot_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	robot_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	robot_face.size = Vector2(CELL_SIZE, CELL_SIZE)
	robot_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(robot_face)


func update_robot_position():
	var pixel_position = Vector2(
		robot_position.x * CELL_SIZE,
		robot_position.y * CELL_SIZE
	)
	robot.position = pixel_position
	if robot_face:
		robot_face.position = pixel_position
		if robot_direction == Vector2i(1, 0):
			robot_face.text = "▶"
		elif robot_direction == Vector2i(0, 1):
			robot_face.text = "▼"
		elif robot_direction == Vector2i(-1, 0):
			robot_face.text = "◀"
		elif robot_direction == Vector2i(0, -1):
			robot_face.text = "▲"


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


func wall_ahead() -> bool:
	var next_position := robot_position + robot_direction

	if next_position.x < 0 or next_position.x >= GRID_WIDTH:
		return true

	if next_position.y < 0 or next_position.y >= GRID_HEIGHT:
		return true

	if next_position in WALLS:
		return true

	return false


func wall_left() -> bool:
	var left_direction := Vector2i(
		robot_direction.y,
		-robot_direction.x
	)

	var next_position := robot_position + left_direction

	if next_position.x < 0 or next_position.x >= GRID_WIDTH:
		return true

	if next_position.y < 0 or next_position.y >= GRID_HEIGHT:
		return true

	if next_position in WALLS:
		return true

	return false


func wall_right() -> bool:
	var right_direction := Vector2i(
		-robot_direction.y,
		robot_direction.x
	)

	var next_position := robot_position + right_direction

	if next_position.x < 0 or next_position.x >= GRID_WIDTH:
		return true

	if next_position.y < 0 or next_position.y >= GRID_HEIGHT:
		return true

	if next_position in WALLS:
		return true

	return false


func _input(event):
	if event.is_action_pressed("ui_right"):
		execute_command("move")
	if event.is_action_pressed("ui_up"):
		turn_right()
	if event.is_action_pressed("ui_down"):
		turn_left()


func turn_right():
	robot_direction = Vector2i(-robot_direction.y, robot_direction.x)
	update_robot_position()


func turn_left():
	robot_direction = Vector2i(robot_direction.y, -robot_direction.x)
	update_robot_position()


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
	var program := []
	var line_number := 0
	var i := 0

	while i < lines.size():
		line_number += 1

		var line: String = lines[i]
		var stripped := line.strip_edges()

		if stripped == "":
			i += 1
			continue

		# Check for a for loop
		if stripped.begins_with("for "):
			var loop: Variant = parse_for_loop(stripped)

			if loop == null:
				var message := "Line %d: Invalid for loop" % line_number
				print(message)
				show_error(message)
				program_running = false
				return

			var repeat_count: int = loop["count"]

			if repeat_count > 20:
				var message := "Line %d: Loop cannot repeat more than 20 times" % line_number
				print(message)
				show_error(message)
				program_running = false
				return

			i += 1

			var body := []

			while i < lines.size():
				var body_line: String = lines[i]

				if body_line.strip_edges() == "":
					i += 1
					continue

				# Check for an if statement inside the for loop
				if (
					body_line.strip_edges() == "if wall_ahead():" or
					body_line.strip_edges() == "if wall_left():" or
					body_line.strip_edges() == "if wall_right():"
				) and (
					body_line.begins_with("    ") and not body_line.begins_with("        ")
				):
					var if_line_number := i + 1
					i += 1

					var if_body := []

					while i < lines.size():
						var if_body_line: String = lines[i]

						if if_body_line.strip_edges() == "":
							i += 1
							continue

						if if_body_line.begins_with("        "):
							if_body.append({
								"command": if_body_line.strip_edges(),
								"line": if_line_number
							})
							i += 1
						else:
							break

					if if_body.is_empty():
						var message := "Line %d: If statement has no indented body" % if_line_number
						print(message)
						show_error(message)
						program_running = false
						return

					var else_body := []

					# Check for else
					if i < lines.size() and lines[i].strip_edges() == "else:":
						i += 1

						while i < lines.size():
							var else_line: String = lines[i]

							if else_line.strip_edges() == "":
								i += 1
								continue

							if else_line.begins_with("        "):
								else_body.append({
									"command": else_line.strip_edges(),
									"line": if_line_number
								})
								i += 1
							else:
								break

						if else_body.is_empty():
							var message := "Line %d: Else statement has no indented body" % if_line_number
							print(message)
							show_error(message)
							program_running = false
							return

					body.append({
						"type": "if",
						"condition": body_line.strip_edges().trim_prefix("if ").trim_suffix(":"),
						"if_body": if_body,
						"else_body": else_body,
						"line": if_line_number
					})

					continue

				# Normal command directly inside the for loop
				if body_line.begins_with("    ") and not body_line.begins_with("        "):
					body.append({
						"type": "command",
						"command": body_line.strip_edges(),
						"line": line_number
					})
					i += 1
					continue

				break

			if body.is_empty():
				var message := "Line %d: For loop has no indented body" % line_number
				print(message)
				show_error(message)
				program_running = false
				return

			# Expand the loop
			for repeat in range(repeat_count):
				for instruction in body:
					program.append(instruction)

			continue

		# Check for a top-level if statement
		if (
			stripped == "if wall_ahead():" or
			stripped == "if wall_left():" or
			stripped == "if wall_right():"
		):
			var if_line_number := line_number
			i += 1

			var if_body := []

			while i < lines.size():
				var body_line: String = lines[i]

				if body_line.strip_edges() == "":
					i += 1
					continue

				if body_line.begins_with("    "):
					if_body.append({
						"command": body_line.strip_edges(),
						"line": if_line_number
					})
					i += 1
				else:
					break

			if if_body.is_empty():
				var message := "Line %d: If statement has no indented body" % if_line_number
				print(message)
				show_error(message)
				program_running = false
				return

			var else_body := []

			# Check for top-level else
			if i < lines.size() and lines[i].strip_edges() == "else:":
				i += 1

				while i < lines.size():
					var else_line: String = lines[i]

					if else_line.strip_edges() == "":
						i += 1
						continue

					if else_line.begins_with("    "):
						else_body.append({
							"command": else_line.strip_edges(),
							"line": if_line_number
						})
						i += 1
					else:
						break

				if else_body.is_empty():
					var message := "Line %d: Else statement has no indented body" % if_line_number
					print(message)
					show_error(message)
					program_running = false
					return

			program.append({
				"type": "if",
				"condition": stripped.trim_prefix("if ").trim_suffix(":"),
				"if_body": if_body,
				"else_body": else_body,
				"line": if_line_number
			})

			continue

		# Reject standalone else
		if stripped == "else:":
			var message := "Line %d: Unexpected else" % line_number
			print(message)
			show_error(message)
			program_running = false
			return

		# Normal command
		program.append({
			"type": "command",
			"command": stripped,
			"line": line_number
		})

		i += 1

	# Execute program
	for instruction in program:
		var instruction_type: String = instruction["type"]
		var original_line: int = instruction["line"]

		if instruction_type == "if":
			var selected_body = []
			var condition_result := false

			if instruction["condition"] == "wall_ahead()":
				condition_result = wall_ahead()
			elif instruction["condition"] == "wall_left()":
				condition_result = wall_left()
			elif instruction["condition"] == "wall_right()":
				condition_result = wall_right()

			if condition_result:
				selected_body = instruction["if_body"]
			else:
				selected_body = instruction["else_body"]

			for body_instruction in selected_body:
				var command: String = body_instruction["command"]

				var valid := execute_command(command)

				if not valid:
					var message := "Line %d: Unknown command '%s'" % [
						body_instruction["line"],
						command
					]
					print(message)
					show_error(message)
					program_running = false
					return

				await get_tree().create_timer(0.3).timeout

			continue

		var command: String = instruction["command"]
		var valid := execute_command(command)

		if not valid:
			var message := "Line %d: Unknown command '%s'" % [
				original_line,
				command
			]
			print(message)
			show_error(message)
			program_running = false
			return

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


func parse_for_loop(line: String):
	var regex := RegEx.new()
	regex.compile("^for i in range\\(([0-9]+)\\):$")
	var result := regex.search(line)
	if result == null:
		return null
	var count := int(result.get_string(1))
	return {
		"count": count
	}

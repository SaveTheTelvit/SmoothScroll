tool
extends Container

signal drag_started

enum State {MOVE, ACCELERATION, INTERPOLATION, NULL}

export var scroll: Vector2 = Vector2.ZERO setget _set_scroll
export(float, 0.0, 1.0) var overscroll_smoothness: float = 0.5 setget _set_overscroll_power
export var horizontal_enabled: bool = true setget _set_horizontal
export var vertical_enabled: bool = true setget _set_vertical
export var overscrolling_horizontal: bool = true
export var overscrolling_vertical: bool = true

var drag_speed: Vector2 = Vector2.ZERO
var last_accum: Vector2 = Vector2.ZERO
var accum: Vector2 = Vector2.ZERO
var state: int = State.NULL
var dragging: bool = false

var control: Control = null
var control_size: Vector2 = Vector2.ZERO
var root_power: float = 2.0

func _set_scroll(value: Vector2) -> void:
	scroll = value
	_update_children()

func _set_overscroll_power(value: float) -> void:
	overscroll_smoothness = value
	if value > 0: root_power = 1 / value
	else: root_power = 1

func _set_horizontal(value: bool) -> void:
	horizontal_enabled = value
	_update_children()

func _set_vertical(value: bool) -> void:
	vertical_enabled = value
	_update_children()

func add_to_scroll(value: Vector2) -> void:
	var max_scroll: Vector2 = get_max_scroll()
	scroll.x = get_new_scroll(scroll.x, value.x, max_scroll.x, overscrolling_horizontal)
	scroll.y = get_new_scroll(scroll.y, value.y, max_scroll.y, overscrolling_vertical)
	_update_children()

func get_new_scroll(scroll: float, add_value: float, max_value: float, overscroll: bool) -> float:
	var new_scroll: float = scroll + add_value
	if sign(new_scroll) == sign(add_value):
		if new_scroll < 0.0:
			if !overscroll: return 0.0
			return -get_new_overscroll(-scroll, -add_value)
		elif new_scroll > max_value:
			if !overscroll: return max_value
			return max_value + get_new_overscroll(scroll - max_value, add_value)
	return new_scroll

func get_new_overscroll(current_overscroll: float, added: float) -> float:
	if current_overscroll < 0:
		added += current_overscroll
		current_overscroll = 0.0
	if overscroll_smoothness == 0.0: return 0.0
	return pow(pow(current_overscroll, root_power) + added, overscroll_smoothness)

func get_current_overscroll(signed: bool = false) -> Vector2:
	var max_scroll: Vector2 = get_max_scroll()
	return Vector2(
		get_axis_overscroll(scroll.x, max_scroll.x, signed),
		get_axis_overscroll(scroll.y, max_scroll.y, signed)
	)

func get_axis_overscroll(scroll: float, max_scroll: float, signed: float) -> float:
	if scroll < 0.0:
		return scroll if signed else -scroll
	elif scroll > max_scroll:
		return scroll - max_scroll
	return 0.0

func get_current_resist() -> Vector2:
	var overscroll: Vector2 = get_current_overscroll()
	return Vector2(get_resist_on_overscroll(overscroll.x), get_resist_on_overscroll(overscroll.y))

func get_resist_on_overscroll(overscroll: float) -> float:
	if overscroll <= 1.0 || overscroll_smoothness == 1.0: return 1.0
	return pow(overscroll, root_power) * (1 - overscroll_smoothness)

func _clips_input() -> bool: return true

func _get_configuration_warning() -> String:
	if control: return ""
	return "SmoothScroll is designed to work with a single child control.\n" + \
		   "Use a child container (VBox, HBox, etc.), or Control, and set the minimum size manually."

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if !event.is_pressed(): return
		match event.button_index:
			BUTTON_WHEEL_UP:
				if Input.is_key_pressed(KEY_SHIFT):
					_imitate_drag(Vector2(-get_avaible_space().x / 8 * event.factor, 0))
				else:
					_imitate_drag(Vector2(0, -get_avaible_space().y / 8 * event.factor))
			BUTTON_WHEEL_DOWN:
				if Input.is_key_pressed(KEY_SHIFT):
					_imitate_drag(Vector2(get_avaible_space().x / 8 * event.factor, 0))
				else:
					_imitate_drag(Vector2(0, get_avaible_space().y / 8 * event.factor))
			BUTTON_WHEEL_LEFT:
				_imitate_drag(Vector2(-get_avaible_space().x / 8 * event.factor, 0))
			BUTTON_WHEEL_RIGHT:
				_imitate_drag(Vector2(get_avaible_space().x / 8 * event.factor, 0))
	elif event is InputEventScreenDrag:
		if !dragging:
			if event.relative.length() < 2.5: return
			dragging = true
			emit_signal("drag_started")
		var move_value = -event.relative
		if !horizontal_enabled: move_value.x = 0
		if !vertical_enabled: move_value.y = 0
		add_to_scroll(move_value)
		accum += move_value
	elif event is InputEventScreenTouch:
		if event.is_pressed():
			_cancel_drag()
			set_physics_process_internal(true)
			state = State.ACCELERATION
		else: state = State.INTERPOLATION

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN: 
			_update_children()
			set_physics_process_internal(true)
			state = State.MOVE
		NOTIFICATION_READY: 
			rect_clip_content = true
			set_physics_process_internal(false)
		NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
			var delta: float = get_physics_process_delta_time()
			match state:
				State.MOVE:
					move_internal_process(delta)
				State.ACCELERATION:
					acceleration_internal_process(delta)
				State.INTERPOLATION:
					if drag_speed == Vector2.ZERO: 
						acceleration_internal_process(delta)
					move_internal_process(delta)
					state = State.MOVE

func move_internal_process(delta: float) -> void:
	var current_overscroll: Vector2 = get_current_overscroll(true)
	var move: Vector2 = Vector2(
		_get_move(drag_speed.x, delta, current_overscroll.x),
		_get_move(drag_speed.y, delta, current_overscroll.y)
	)
	if move.length() == 0.0:
		_cancel_drag()
		return
	add_to_scroll(move)
	var resist: Vector2 = get_current_resist()
	drag_speed = Vector2(
		_get_new_speed(drag_speed.x, 1000 * resist.x * delta),
		_get_new_speed(drag_speed.y, 1000 * resist.y * delta)
	)

func acceleration_internal_process(delta: float) -> void:
	var diff : Vector2 = accum - last_accum
	last_accum = accum
	drag_speed = diff / delta

func _get_new_speed(speed: float, dump: float) -> float:
	var val_sign: float = sign(speed)
	speed = abs(speed) - dump
	if speed <= 0.0: return 0.0
	return val_sign * speed

func _get_move(speed: float, delta: float, overscroll: float) -> float:
	if speed == 0.0:
		if overscroll == 0.0: return 0.0
		return _get_return_move(delta, overscroll)
	return speed * delta

func _get_return_move(delta: float, overscroll: float) -> float:
	var value: float = 10 * delta * max(abs(overscroll), 1)
	if abs(overscroll) - value <= 0: return -overscroll
	return sign(overscroll) * -value

func _imitate_drag(value: Vector2) -> void:
	drag_speed += Vector2(
		sign(value.x) * sqrt(2000 * abs(value.x)), 
		sign(value.y) * sqrt(2000 * abs(value.y))
	)
	if !horizontal_enabled: drag_speed.x = 0
	if !vertical_enabled: drag_speed.y = 0
	state = State.MOVE
	set_physics_process_internal(true)

func _cancel_drag():
	accum = Vector2.ZERO
	last_accum = Vector2.ZERO
	drag_speed = Vector2.ZERO
	dragging = false
	state = State.NULL
	set_physics_process_internal(false)

func _update_children() -> void:
	if get_child_count() == 0: 
		control = null
		update_configuration_warning()
		return
	var finded: Node = get_container()
	if !finded || !(finded is Control): 
		control = null
		update_configuration_warning()
		return
	if finded.get_position_in_parent() != 0: move_child(finded, 0)
	control = finded
	var rect: Rect2 = get_child_rect(control)
	control_size = rect.size
	rect.position -= scroll
	fit_child_in_rect(control, rect)

func get_container() -> Node:
	if get_child_count() == 0: return null
	return get_child(0)

func get_max_scroll() -> Vector2:
	var value: Vector2 = control_size - get_avaible_space()
	if value.x < 0.0: value.x = 0.0
	if value.y < 0.0: value.y = 0.0
	return value

func get_avaible_space() -> Vector2:
	return rect_size

func get_child_rect(child: Control) -> Rect2:
	var avaible_space: Vector2 = get_avaible_space()
	child.rect_size = Vector2(
		get_size_on_flag(child.size_flags_horizontal, avaible_space.x),
		get_size_on_flag(child.size_flags_vertical, avaible_space.y)
	)
	var position: Vector2 = Vector2(
		get_position_on_flag(child.size_flags_horizontal, avaible_space.x, child.rect_size.x),
		get_position_on_flag(child.size_flags_vertical, avaible_space.y, child.rect_size.y)
	)
	return Rect2(position, child.rect_size)

func get_size_on_flag(flag: int, avaible_space: float) -> float:
	if flag & SIZE_FILL && flag & SIZE_EXPAND: return avaible_space
	return 0.0

func get_position_on_flag(flag: int, avaible_space: float, size: float) -> float:
	var value: float = 0.0
	if !(flag & SIZE_EXPAND) || flag & SIZE_FILL: value = 0.0
	elif flag & SIZE_SHRINK_END: value = avaible_space - size
	elif flag & SIZE_SHRINK_CENTER: value = (avaible_space - size) * 0.5
	if value < 0.0: return 0.0
	return value

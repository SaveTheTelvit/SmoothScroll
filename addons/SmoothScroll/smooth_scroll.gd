tool
extends Container

class_name SmoothScroll

enum Move { NULL, DRAG, RETURN }

export var scroll: Vector2 = Vector2.ZERO setget _set_scroll
export(float, 0.0, 1.0) var overscroll_power: float = 0.5 setget _set_overscroll_power
export var horizontal_enabled: bool = true setget _set_horizontal
export var vertical_enabled: bool = true setget _set_vertical

var drag_speed: Vector2 = Vector2.ZERO
var last_accum: Vector2 = Vector2.ZERO
var accum: Vector2 = Vector2.ZERO
var await_time: float = 0.0
var move: int = Move.NULL

var control: Control = null
var control_size: Vector2 = Vector2.ZERO
var root_power: float = 2.0

func _set_scroll(value: Vector2) -> void:
	scroll = value
	_update_children()

func _set_overscroll_power(value: float) -> void:
	overscroll_power = value
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
	scroll.x = get_new_scroll(scroll.x, value.x, max_scroll.x)
	scroll.y = get_new_scroll(scroll.y, value.y, max_scroll.y)
	_update_children()

func get_new_scroll(scroll: float, add_value: float, max_value: float) -> float:
	var new_scroll: float = scroll + add_value
	if sign(new_scroll) == sign(add_value):
		if new_scroll < 0.0:
			new_scroll = -get_overscroll(-scroll, -add_value)
		elif new_scroll > max_value:
			new_scroll = max_value + get_overscroll(scroll - max_value, add_value)
	return new_scroll

func get_overscroll(current_overscroll: float, added: float) -> float:
	if current_overscroll < 0:
		current_overscroll = 0.0
		added += current_overscroll
	return pow(pow(current_overscroll, root_power) + added, overscroll_power)

func get_current_overscroll(signed: bool = false) -> Vector2:
	var max_scroll: Vector2 = get_max_scroll()
	var overscroll: Vector2 = Vector2.ZERO
	if scroll.x < 0.0:
		if signed: overscroll.x = scroll.x
		else: overscroll.x = -scroll.x
	elif scroll.x > max_scroll.x:
		overscroll.x = scroll.x - max_scroll.x
	if scroll.y < 0.0:
		if signed: overscroll.y = scroll.y
		else: overscroll.y = -scroll.y
	elif scroll.y > max_scroll.y:
		overscroll.y = scroll.y - max_scroll.y
	return overscroll

func get_current_resist() -> Vector2:
	var overscroll: Vector2 = get_current_overscroll()
	return Vector2(get_resist_on_overscroll(overscroll.x), get_resist_on_overscroll(overscroll.y))

func get_resist_on_overscroll(overscroll: float) -> float:
	if overscroll <= 1.0: return 1.0
	return pow(overscroll, 1.0001)

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
		var move_value = -event.relative
		if !horizontal_enabled: move_value.x = 0
		if !vertical_enabled: move_value.y = 0
		add_to_scroll(move_value)
		accum += move_value
	elif event is InputEventScreenTouch:
		if event.is_pressed():
			_cancel_drag()
			set_physics_process_internal(true)
		else:
			if drag_speed.length() > 0.0:
				move = Move.DRAG
			else:
				_return()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN: _update_children()
		NOTIFICATION_READY: 
			rect_clip_content = true
			set_physics_process_internal(false)
		NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
			var delta: float = get_physics_process_delta_time()
			if move == Move.DRAG:
				var resist: Vector2 = get_current_resist()
				var _sign_x: int = sign(drag_speed.x)
				var _sign_y: int = sign(drag_speed.y)
				var _val_x: float = abs(drag_speed.x) - 1000 * delta * resist.x
				var _val_y: float = abs(drag_speed.y) - 1000 * delta * resist.y
				if _val_x < 0: _val_x = 0.0
				if _val_y < 0: _val_y = 0.0
				add_to_scroll(drag_speed * delta)
				drag_speed = Vector2(_val_x * _sign_x, _val_y * _sign_y)
				if drag_speed.length() == 0.0: _return()
			elif move == Move.RETURN:
				await_time -= delta
				if await_time <= 0.0:
					var overscroll: Vector2 = get_current_overscroll(true)
					var direction: Vector2 = -overscroll.normalized()
					var move_value: Vector2 = direction * 1000 * delta
					var result: Vector2 = overscroll.abs() - move_value.abs()
					if result.x <= 0 && result.y <= 0:
						_cancel_drag()
						move_value = -overscroll
					add_to_scroll(move_value)
			else:
				var diff : Vector2 = accum - last_accum
				last_accum = accum
				drag_speed = diff / delta

func _imitate_drag(value: Vector2) -> void:
	drag_speed += Vector2(sign(value.x) * 1000, sign(value.y) * 1000) * 0.2
	if !horizontal_enabled: drag_speed.x = 0
	if !vertical_enabled: drag_speed.y = 0
	move = Move.DRAG
	set_physics_process_internal(true)

func _return() -> void:
	accum = Vector2.ZERO
	last_accum = Vector2.ZERO
	drag_speed = Vector2.ZERO
	await_time = 0.05
	move = Move.RETURN
	set_physics_process_internal(true)

func _cancel_drag():
	accum = Vector2.ZERO
	last_accum = Vector2.ZERO
	drag_speed = Vector2.ZERO
	move = Move.NULL
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
	return control_size - get_avaible_space()

func get_avaible_space() -> Vector2:
	return rect_size

func get_child_rect(child: Control) -> Rect2:
	var avaible_space: Vector2 = rect_size
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

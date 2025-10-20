tool
extends "res://addons/SmoothScroll/smooth_scroll.gd"

var h_scrollbar: HScrollBar = HScrollBar.new()
var v_scrollbar: VScrollBar = VScrollBar.new()

func _on_v_value_changed(value: float) -> void:
	if value == scroll.y || get_current_overscroll().y != 0: return
	scroll.y = value
	_update_children()

func _on_h_value_changed(value: float) -> void:
	if value == scroll.x || get_current_overscroll().x != 0: return
	scroll.x = value
	_update_children()

func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		v_scrollbar.connect("value_changed", self, "_on_v_value_changed")
		h_scrollbar.connect("value_changed", self, "_on_h_value_changed")
		add_child(h_scrollbar)
		add_child(v_scrollbar)

func get_container() -> Node:
	for child in get_children():
		if child == h_scrollbar || child == v_scrollbar:
			continue
		return child
	return null

func _update_children() -> void:
	._update_children()
	_update_scrollbars()

func _update_scrollbars() -> void:
	if h_scrollbar.get_parent() != self || v_scrollbar.get_parent() != self: return
	h_scrollbar.visible = horizontal_enabled && control_size.x > rect_size.x
	v_scrollbar.visible = vertical_enabled && control_size.y > rect_size.y
	var h_size: Vector2 = get_scrollbar_min_size(h_scrollbar)
	var v_size: Vector2 = get_scrollbar_min_size(v_scrollbar)
	h_size.x = rect_size.x - v_size.x
	v_size.y = rect_size.y - h_size.y
	var h_pos: Vector2 = Vector2(0, rect_size.y - h_size.y)
	var v_pos: Vector2 = Vector2(rect_size.x - v_size.x, 0)
	h_scrollbar.max_value = control_size.x
	v_scrollbar.max_value = control_size.y
	h_scrollbar.value = scroll.x
	v_scrollbar.value = scroll.y
	h_scrollbar.page = rect_size.x
	v_scrollbar.page = rect_size.y
	fit_child_in_rect(h_scrollbar, Rect2(h_pos, h_size))
	fit_child_in_rect(v_scrollbar, Rect2(v_pos, v_size))

func get_scrollbar_min_size(scrollbar: ScrollBar) -> Vector2:
	if !scrollbar.visible: return Vector2.ZERO
	return scrollbar.get_minimum_size()

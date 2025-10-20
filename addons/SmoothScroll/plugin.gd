tool
extends EditorPlugin

func _enter_tree():
	add_custom_type("SmoothScroll", "Container", preload("smooth_scroll.gd"), preload("SmoothScroll.svg"))
	add_custom_type("BarSmoothScroll", "Container", preload("bar_smooth_scroll.gd"), preload("SmoothScroll.svg"))

func _exit_tree():
	remove_custom_type("SmoothScroll")
	remove_custom_type("BarSmoothScroll")

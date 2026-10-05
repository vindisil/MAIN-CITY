extends Button
# Every mobile control owns its own screen-finger index. Godot's emulated
# mouse pointer must not replace one held touch with another touch.
var active_finger: int = -1
var mobile_multitouch: bool = false

func _ready() -> void:
    mobile_multitouch = OS.has_feature("mobile")
    if mobile_multitouch:
        # The touch goes to _input, not the GUI mouse/button capture system.
        mouse_filter = Control.MOUSE_FILTER_IGNORE
        process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
    if mobile_multitouch:
        var cursor_active := bool(get_tree().get_meta("br1_virtual_cursor_active", false))
        mouse_filter = Control.MOUSE_FILTER_STOP if cursor_active else Control.MOUSE_FILTER_IGNORE
        if cursor_active or get_tree().paused or disabled or not is_visible_in_tree():
            _release_finger(false)

func _input(event: InputEvent) -> void:
    if bool(get_tree().get_meta("br1_virtual_cursor_active", false)):
        return
    if not mobile_multitouch:
        return
    if get_tree().paused or disabled or not is_visible_in_tree():
        _release_finger(false)
        return
    if not (event is InputEventScreenTouch):
        return
    var touch: InputEventScreenTouch = event as InputEventScreenTouch
    if touch.pressed:
        if active_finger == -1 and get_global_rect().has_point(touch.position):
            active_finger = touch.index
            modulate = Color(0.75, 0.92, 1.0)
            button_down.emit()
    elif touch.index == active_finger:
        _release_finger(not touch.canceled and get_global_rect().has_point(touch.position))

func _release_finger(activate: bool) -> void:
    if active_finger == -1:
        return
    active_finger = -1
    modulate = Color.WHITE
    button_up.emit()
    if activate:
        if toggle_mode:
            button_pressed = not button_pressed
        else:
            pressed.emit()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _release_finger(false)
    elif what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree():
        _release_finger(false)

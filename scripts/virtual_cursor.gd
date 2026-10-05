extends CanvasLayer
## BR1 v0.0.116 - cursor virtual tipo trackpad para mobile e mouse livre sincronizado no PC.

var p: Node = null
var active: bool = false
var cursor_pos: Vector2 = Vector2.ZERO
var cursor_label: Label = null
var touch_index: int = -1
var touch_start: Vector2 = Vector2.ZERO
var travel: float = 0.0
var last_touch_pos: Vector2 = Vector2.ZERO
var hold_time: float = 0.0
var drag_click_active: bool = false
const TAP_LIMIT := 18.0
const POINTER_SPEED := 1.15
const HOLD_TO_DRAG := 0.32

func setup(player: Node) -> void:
    p = player
    layer = 500
    cursor_label = Label.new()
    cursor_label.name = "CursorVirtual"
    cursor_label.text = "↖"
    cursor_label.custom_minimum_size = Vector2(36, 36)
    cursor_label.add_theme_font_size_override("font_size", 30)
    cursor_label.add_theme_color_override("font_color", Color(1,1,1,0.98))
    cursor_label.add_theme_color_override("font_shadow_color", Color(0,0,0,0.95))
    cursor_label.add_theme_constant_override("shadow_offset_x", 2)
    cursor_label.add_theme_constant_override("shadow_offset_y", 2)
    cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cursor_label.visible = false
    add_child(cursor_label)
    cursor_pos = get_viewport().get_visible_rect().size * 0.5
    _update_visual()
    get_tree().set_meta("br1_virtual_cursor_active", false)

func toggle_mode() -> void:
    set_enabled(not active)

func set_enabled(value: bool) -> void:
    if active and not value and drag_click_active:
        _send_click(false)
    active = value
    get_tree().set_meta("br1_virtual_cursor_active", active)
    touch_index = -1
    travel = 0.0
    hold_time = 0.0
    drag_click_active = false
    if OS.has_feature("mobile"):
        cursor_label.visible = active
        if active:
            cursor_pos = get_viewport().get_visible_rect().size * 0.5
            _update_visual()
    else:
        cursor_label.visible = false
        if active:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        else:
            var keep_visible := false
            if p != null and is_instance_valid(p):
                if p.has_method("_chat_is_typing") and bool(p.call("_chat_is_typing")):
                    keep_visible = true
                var menu: Variant = p.get("modern_ui")
                if menu != null and is_instance_valid(menu) and bool(menu.get("menu_open")):
                    keep_visible = true
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if keep_visible else Input.MOUSE_MODE_CAPTURED

func is_enabled() -> bool:
    return active


func _process(delta: float) -> void:
    if not active or not OS.has_feature("mobile") or touch_index == -1:
        return
    hold_time += delta
    # Segurar sem arrastar vira botao esquerdo pressionado. Depois e possivel
    # arrastar sliders e outros controles como com um mouse real.
    if not drag_click_active and travel <= TAP_LIMIT and hold_time >= HOLD_TO_DRAG:
        drag_click_active = true
        _send_click(true)
        if cursor_label != null:
            cursor_label.modulate = Color(0.55, 1.0, 0.82, 1.0)

func _input(event: InputEvent) -> void:
    if not active:
        return
    if not OS.has_feature("mobile"):
        if event is InputEventMouseMotion:
            cursor_pos = (event as InputEventMouseMotion).position
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and touch_index == -1:
            touch_index = touch.index
            touch_start = touch.position
            last_touch_pos = touch.position
            travel = 0.0
            hold_time = 0.0
            drag_click_active = false
            get_viewport().set_input_as_handled()
        elif not touch.pressed and touch.index == touch_index:
            if drag_click_active:
                _send_click(false)
            elif travel <= TAP_LIMIT:
                _send_click(true)
                _send_click(false)
            touch_index = -1
            travel = 0.0
            hold_time = 0.0
            drag_click_active = false
            if cursor_label != null:
                cursor_label.modulate = Color.WHITE
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == touch_index:
            var delta := drag.position - last_touch_pos
            last_touch_pos = drag.position
            travel += delta.length()
            cursor_pos += delta * POINTER_SPEED
            _clamp_cursor()
            _update_visual()
            _send_motion(delta * POINTER_SPEED)
            get_viewport().set_input_as_handled()

func _clamp_cursor() -> void:
    var bounds := get_viewport().get_visible_rect().size
    cursor_pos.x = clampf(cursor_pos.x, 2.0, maxf(2.0, bounds.x - 2.0))
    cursor_pos.y = clampf(cursor_pos.y, 2.0, maxf(2.0, bounds.y - 2.0))

func _update_visual() -> void:
    if cursor_label != null:
        cursor_label.position = cursor_pos - Vector2(5.0, 6.0)

func _send_motion(relative_motion: Vector2) -> void:
    var ev := InputEventMouseMotion.new()
    ev.position = cursor_pos
    ev.global_position = cursor_pos
    ev.relative = relative_motion
    ev.button_mask = MOUSE_BUTTON_MASK_LEFT if drag_click_active else 0
    Input.parse_input_event(ev)

func _send_click(pressed_value: bool) -> void:
    var ev := InputEventMouseButton.new()
    ev.position = cursor_pos
    ev.global_position = cursor_pos
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = pressed_value
    Input.parse_input_event(ev)

func _exit_tree() -> void:
    if get_tree() != null:
        get_tree().set_meta("br1_virtual_cursor_active", false)

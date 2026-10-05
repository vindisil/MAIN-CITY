extends Control

signal finished(save_changes: bool, positions: Dictionary)

var targets: Dictionary = {}
var active_key: String = ""
var drag_pointer: int = -100
var drag_last: Vector2 = Vector2.ZERO
var viewport_dimensions: Vector2 = Vector2.ONE

func configure(items: Dictionary) -> void:
    targets = items
    viewport_dimensions = get_viewport_rect().size
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_STOP
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _create_toolbar()
    queue_redraw()

func _create_toolbar() -> void:
    var bar := PanelContainer.new()
    bar.name = "HUDToolbar"
    bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    bar.offset_bottom = 64.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.015, 0.04, 0.075, 0.94)
    bar.add_theme_stylebox_override("panel", style)
    add_child(bar)
    var row := HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    bar.add_child(row)
    var title := Label.new()
    title.text = "ARRASTE OS CONTROLES"
    title.add_theme_font_size_override("font_size", 15)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(title)
    for data in [["SALVAR", true], ["CANCELAR", false]]:
        var action := Button.new()
        action.text = data[0]
        action.custom_minimum_size = Vector2(105, 48)
        action.focus_mode = Control.FOCUS_NONE
        row.add_child(action)
        action.pressed.connect(_finish.bind(data[1]))

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.15), true)
    for key in targets:
        var target: Control = targets[key] as Control
        if not is_instance_valid(target) or not target.is_visible_in_tree():
            continue
        var rect: Rect2 = target.get_global_rect()
        var color := Color(0.20, 1.0, 0.76, 1.0) if key == active_key else Color(0.26, 0.70, 1.0, 0.75)
        draw_rect(Rect2(rect.position - global_position, rect.size), color, false, 2.0)

func _select_at(point: Vector2) -> void:
    active_key = ""
    if point.y < 66.0:
        return
    var keys := targets.keys()
    keys.reverse()
    for key in keys:
        var target: Control = targets[key] as Control
        if is_instance_valid(target) and target.is_visible_in_tree() and target.get_global_rect().has_point(point):
            active_key = key
            return

func _drag_to(pos: Vector2) -> void:
    if not targets.has(active_key):
        return
    var target: Control = targets[active_key] as Control
    if not is_instance_valid(target):
        return
    var rect: Rect2 = target.get_global_rect()
    var delta: Vector2 = pos - drag_last
    var screen: Vector2 = get_viewport_rect().size
    var next_pos: Vector2 = rect.position + delta
    next_pos.x = clampf(next_pos.x, 0.0, maxf(0.0, screen.x - rect.size.x))
    next_pos.y = clampf(next_pos.y, 68.0, maxf(68.0, screen.y - rect.size.y))
    target.position += next_pos - rect.position
    drag_last = pos
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and drag_pointer == -100:
            _select_at(touch.position)
            if active_key != "":
                drag_pointer = touch.index
                drag_last = touch.position
            queue_redraw()
        elif not touch.pressed and drag_pointer == touch.index:
            drag_pointer = -100
            active_key = ""
            queue_redraw()
        accept_event()
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index == drag_pointer:
            _drag_to(drag.position)
        accept_event()
    elif event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.button_index == MOUSE_BUTTON_LEFT:
            if click.pressed:
                _select_at(click.position)
                if active_key != "":
                    drag_pointer = -1
                    drag_last = click.position
            elif drag_pointer == -1:
                drag_pointer = -100
                active_key = ""
            queue_redraw()
        accept_event()
    elif event is InputEventMouseMotion and drag_pointer == -1:
        _drag_to((event as InputEventMouseMotion).position)
        accept_event()

func _finish(save_changes: bool) -> void:
    var positions: Dictionary = {}
    if save_changes:
        var screen: Vector2 = get_viewport_rect().size
        for key in targets:
            var target: Control = targets[key] as Control
            if is_instance_valid(target):
                positions[key] = target.get_global_rect().get_center() / screen
    finished.emit(save_changes, positions)

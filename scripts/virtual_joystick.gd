extends Control
## Joystick de movimento e direcao: tamanho da V77 reduzido em 25%.
## Compartilhado entre o jogador a pe e o volante analogico dos veiculos.

var value := Vector2.ZERO
var active_touch := -1
var center := Vector2.ZERO
var radius := 117.0 # V78: 75% do curso da V77 (156 px); valor normalizado permanece igual.
var driving_mode: bool = false
var drag_started: bool = false
@export_range(2.0, 24.0, 1.0) var drag_threshold: float = 8.0

const KNOB_RADIUS := 29.25

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE if OS.has_feature("mobile") else Control.MOUSE_FILTER_STOP
    queue_redraw()

func get_value() -> Vector2:
    return value

func _effective_radius() -> float:
    # Nunca deixe o disco sair do controle redimensionado pelo editor da HUD.
    return maxf(1.0, minf(radius, minf(size.x, size.y) * 0.5 - KNOB_RADIUS - 4.0))

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and active_touch == -2:
        _reset_touch()
    if bool(get_tree().get_meta("br1_virtual_cursor_active", false)):
        _reset_touch()
        return
    if get_tree().paused or not is_visible_in_tree():
        _reset_touch()
        return
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        if touch.pressed and active_touch == -1 and get_global_rect().has_point(touch.position):
            _begin_touch(touch.index, touch.position)
        elif not touch.pressed and touch.index == active_touch:
            _reset_touch()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        if drag.index == active_touch:
            _update_value(drag.position)

func _reset_touch() -> void:
    if active_touch == -1 and value == Vector2.ZERO:
        return
    active_touch = -1
    drag_started = false
    value = Vector2.ZERO
    queue_redraw()

func _begin_touch(index: int, pos: Vector2) -> void:
    # O ponto pressionado vira a origem: tocar fora do centro nao move o jogador.
    active_touch = index
    center = pos
    drag_started = false
    value = Vector2.ZERO
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    # Preview da HUD no PC; o toque no celular e processado por _input.
    if OS.has_feature("mobile"):
        return
    if event.device == -1:
        return
    if event is InputEventMouseButton:
        var click: InputEventMouseButton = event as InputEventMouseButton
        if click.button_index == MOUSE_BUTTON_LEFT:
            if click.pressed and active_touch == -1:
                _begin_touch(-2, click.position)
            elif active_touch == -2:
                _reset_touch()
            accept_event()
    elif event is InputEventMouseMotion and active_touch == -2:
        _update_value((event as InputEventMouseMotion).position)
        accept_event()

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _reset_touch()
    elif what == NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree():
        _reset_touch()
    elif what == NOTIFICATION_RESIZED:
        queue_redraw()

func _update_value(pos: Vector2) -> void:
    var travel: float = _effective_radius()
    var offset := pos - center
    if offset.length() <= drag_threshold:
        value = Vector2.ZERO
    else:
        drag_started = true
        value = offset.normalized() * clampf((offset.length() - drag_threshold) / travel, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    if size.x <= 0.0 or size.y <= 0.0:
        return
    var c: Vector2 = size * 0.5
    var travel: float = _effective_radius()
    var outer: float = travel + 16.5
    var accent: Color = Color(0.24, 0.96, 0.77) if not driving_mode else Color(0.35, 0.72, 1.0)
    var secondary: Color = Color(0.10, 0.43, 0.42) if not driving_mode else Color(0.12, 0.29, 0.57)
    var pressed: bool = active_touch != -1

    # Aro em camadas e marcacoes direcionais, desenhados sem texturas extras.
    draw_circle(c + Vector2(0.0, 2.25), outer + 3.0, Color(0.0, 0.0, 0.0, 0.25))
    draw_circle(c, outer, Color(0.015, 0.028, 0.045, 0.38))
    draw_circle(c, travel + 3.75, Color(0.018, 0.052, 0.075, 0.43))
    draw_circle(c, travel * 0.64, Color(0.025, 0.080, 0.105, 0.26))
    draw_arc(c, outer - 1.5, -PI * 0.5, PI * 1.5, 72, accent * Color(1.0, 1.0, 1.0, 0.60), 3.0, true)
    draw_arc(c, travel + 4.5, -PI * 0.5, PI * 1.5, 72, secondary * Color(1.0, 1.0, 1.0, 0.70), 2.0, true)
    for index in range(8):
        var angle: float = TAU * float(index) / 8.0
        var direction: Vector2 = Vector2(cos(angle), sin(angle))
        var a: Vector2 = c + direction * (outer - 8.25)
        var b: Vector2 = c + direction * (outer - (15.75 if index % 2 == 0 else 12.0))
        draw_line(a, b, Color(accent.r, accent.g, accent.b, 0.70 if index % 2 == 0 else 0.38), 3.0 if index % 2 == 0 else 2.0, true)

    var thumb: Vector2 = c + value * travel
    draw_circle(thumb + Vector2(0.0, 3.0), KNOB_RADIUS + 3.0, Color(0.0, 0.0, 0.0, 0.35))
    draw_circle(thumb, KNOB_RADIUS + 1.5, Color(accent.r, accent.g, accent.b, 0.56 if pressed else 0.36))
    draw_circle(thumb, KNOB_RADIUS - 1.5, Color(0.045, 0.13, 0.18, 0.96) if not driving_mode else Color(0.05, 0.105, 0.23, 0.96))
    draw_circle(thumb, KNOB_RADIUS * 0.65, Color(0.12, 0.36, 0.36, 0.94) if not driving_mode else Color(0.15, 0.27, 0.52, 0.94))
    draw_circle(thumb, KNOB_RADIUS * 0.33, Color(accent.r, accent.g, accent.b, 0.95 if pressed else 0.72))
    draw_arc(thumb, KNOB_RADIUS - 2.25, -PI * 0.85, PI * 0.20, 32, Color(0.88, 1.0, 1.0, 0.7), 2.0, true)

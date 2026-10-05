extends Control
## Mapa esquematico do menu de pausa. Desenha apenas construcao, ruas e bairros.
## Escala uniforme, clique/touch -> posicionamento GPS na rua acessivel.

signal destination_selected(world_location: Vector2)
const EXTENT: float = 1230.0
const MAP_MARGIN: float = 15.0
const BUILDING_COLOR: Color = Color("637f94")
const ROAD_COLOR: Color = Color("233e51")
const ROUTE_COLOR: Color = Color("4decc0")
const BAIRROS = preload("res://scripts/neighborhoods.gd")

var data: Dictionary = {}
var navigation: Variant = null
var _elapsed: float = 0.0

func _ready() -> void:
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_NONE
    custom_minimum_size = Vector2(0.0, 315.0)
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
    if parsed is Dictionary:
        data = parsed
    navigation = get_tree().current_scene.get_node_or_null("GPSNavigation")
    if navigation != null:
        navigation.route_changed.connect(queue_redraw)
    resized.connect(queue_redraw)

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= 0.40:
        _elapsed = 0.0
        if visible:
            queue_redraw()

func _map_rect() -> Rect2:
    var edge: float = maxf(10.0, minf(size.x, size.y) - MAP_MARGIN * 2.0)
    return Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)

func _to_screen(world: Vector2) -> Vector2:
    var rect: Rect2 = _map_rect()
    return rect.position + (world + Vector2.ONE * EXTENT) * (rect.size.x / (EXTENT * 2.0))

func _to_world(screen: Vector2) -> Vector2:
    var rect: Rect2 = _map_rect()
    var normalized: Vector2 = (screen - rect.position) / rect.size
    return (normalized * 2.0 - Vector2.ONE) * EXTENT

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color("0a1724"))
    var rect: Rect2 = _map_rect()
    draw_rect(rect, Color("102637"))
    var grid_color: Color = Color("213649")
    for section in range(-2, 3):
        var offset: float = float(section) * 640.0
        draw_line(_to_screen(Vector2(offset, -EXTENT)), _to_screen(Vector2(offset, EXTENT)), grid_color, 1.0)
        draw_line(_to_screen(Vector2(-EXTENT, offset)), _to_screen(Vector2(EXTENT, offset)), grid_color, 1.0)
    var road_width: float = maxf(1.0, 11.0 * rect.size.x / (EXTENT * 2.0))
    for raw_road in data.get("roads", []):
        var road: float = float(raw_road)
        draw_line(_to_screen(Vector2(road, -EXTENT)), _to_screen(Vector2(road, EXTENT)), ROAD_COLOR, road_width)
        draw_line(_to_screen(Vector2(-EXTENT, road)), _to_screen(Vector2(EXTENT, road)), ROAD_COLOR, road_width)
    # Silhuetas de construcoes, excluindo grama, postes, carros e texturas.
    for raw_building in data.get("buildings", []):
        var b: Array = raw_building
        var center: Vector2 = Vector2(float(b[0]), float(b[1]))
        var footprint: Vector2 = Vector2(float(b[2]), float(b[3]))
        var corner: Vector2 = _to_screen(center - footprint * 0.5)
        var dimensions: Vector2 = footprint * rect.size.x / (EXTENT * 2.0)
        draw_rect(Rect2(corner, dimensions), BUILDING_COLOR)
    var font: Font = get_theme_default_font()
    for zi in range(4):
        for xi in range(4):
            var district: Vector2 = Vector2(-960.0 + xi * 640.0, -960.0 + zi * 640.0)
            var label_pos: Vector2 = _to_screen(district)
            var bairro_name: String = BAIRROS.MAP_NAMES[zi * 4 + xi]
            var approx_width: float = font.get_string_size(bairro_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
            draw_rect(Rect2(label_pos + Vector2(-approx_width * 0.5 - 3.0, -13.0), Vector2(approx_width + 6.0, 17.0)), Color(0.05, 0.11, 0.17, 0.92))
            draw_string(font, label_pos - Vector2(approx_width * 0.5, 1.0), bairro_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e4f0f5"))
    if navigation != null:
        if navigation.has_destination:
            var route: PackedVector2Array = navigation.get_route()
            var last: Vector2 = _to_screen(navigation.current_position())
            for point in route:
                var next_point: Vector2 = _to_screen(point)
                draw_line(last, next_point, ROUTE_COLOR, 3.2, true)
                last = next_point
            var marker: Vector2 = _to_screen(navigation.get_destination())
            draw_circle(marker, 7.0, Color("132339"))
            draw_circle(marker, 5.0, Color("ffb454"))
        var me: Vector2 = _to_screen(navigation.current_position())
        draw_circle(me, 7.0, Color("0b1724"))
        draw_circle(me, 4.5, Color("ffffff"))
    draw_rect(rect, Color("57bba9"), false, 1.0)

func _gui_input(event: InputEvent) -> void:
    var click: Vector2 = Vector2.ZERO
    if event is InputEventMouseButton:
        var mouse: InputEventMouseButton = event as InputEventMouseButton
        if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
            return
        click = mouse.position
    elif event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        if not touch.pressed:
            return
        click = touch.position
    else:
        return
    if not _map_rect().has_point(click):
        return
    destination_selected.emit(_to_world(click))
    queue_redraw()
    accept_event()

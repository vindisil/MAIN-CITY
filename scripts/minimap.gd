extends Control

const BAIRROS = preload("res://scripts/neighborhoods.gd")

signal pause_requested
var target: Node3D
var zoom_radius: float = 150.0
var data: Dictionary = {}
var heading: float = 0.0
var full_map := false
var redraw_interval := 0.05
var redraw_timer := 0.0
var origin := Vector3.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    focus_mode = Control.FOCUS_ALL
    tooltip_text = "Pausar e abrir configurações"
    clip_contents = true
    custom_minimum_size = Vector2(196,196)
    var shader := Shader.new()
    shader.code = "shader_type canvas_item; varying vec2 local_position; uniform vec2 center = vec2(98.0); uniform float radius = 97.0; void vertex(){ local_position = VERTEX; } void fragment(){ COLOR.a *= 1.0-smoothstep(radius-1.0,radius,distance(local_position,center)); }"
    var circular := ShaderMaterial.new()
    circular.shader = shader
    material = circular
    resized.connect(_resize_circle)
    _resize_circle()
    var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
    if parsed is Dictionary:
        data = parsed

func set_target(node: Node3D) -> void:
    target = node

func _process(delta: float) -> void:
    redraw_timer += delta
    if redraw_timer < redraw_interval:
        return
    redraw_timer = 0.0
    if is_instance_valid(target):
        origin = target.global_position
    var camera := get_viewport().get_camera_3d()
    if camera:
        heading = camera.global_rotation.y
    queue_redraw()

func _world_to_map(pos: Vector3) -> Vector2:
    var offset := Vector2(pos.x - origin.x, pos.z - origin.z)
    # Godot faces -Z when yaw is zero; canvas Y grows toward the bottom.
    # Rotate world offsets in the SAME sense as camera yaw: the point ahead
    # of the camera must always appear above the centered player arrow.
    return size * 0.5 + offset.rotated(heading) * minf(size.x, size.y) / (2.0 * zoom_radius)

func _line(a: Vector3, b: Vector3, c: Color, width: float) -> void:
    draw_line(_world_to_map(a), _world_to_map(b), c, width, true)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO,size), Color("101c2b"))
    if data.is_empty():
        return
    var scale_px := minf(size.x,size.y) / (zoom_radius * 2.0)
    for b in data.get("buildings", []):
        if absf(float(b[0])-origin.x)>zoom_radius*1.8 or absf(float(b[1])-origin.z)>zoom_radius*1.8:
            continue
        var polygon := PackedVector2Array()
        for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
            polygon.append(_world_to_map(Vector3(b[0]+corner.x*b[2]*0.5,0,b[1]+corner.y*b[3]*0.5)))
        draw_colored_polygon(polygon,Color("2a4055"))
    var extent: float = float(data.get("extent",1230))
    for road in data.get("roads",[]):
        _line(Vector3(road,0,-extent),Vector3(road,0,extent),Color("627c91"),maxf(2.0,22.0*scale_px))
        _line(Vector3(-extent,0,road),Vector3(extent,0,road),Color("627c91"),maxf(2.0,22.0*scale_px))
    # GPS persistente: rota visivel enquanto anda ou dirige, sem gerar 3D.
    var gps: Variant = null
    if get_tree().current_scene != null:
        gps = get_tree().current_scene.get_node_or_null("GPSNavigation")
    if gps != null and gps.has_destination:
        var route: PackedVector2Array = gps.get_route()
        var last: Vector2 = _world_to_map(Vector3(gps.current_position().x, 0.0, gps.current_position().y))
        for point in route:
            var next_point: Vector2 = _world_to_map(Vector3(point.x, 0.0, point.y))
            draw_line(last, next_point, Color("4decc0"), 3.0, true)
            last = next_point
        var end_point: Vector2 = gps.get_destination()
        var mark: Vector2 = _world_to_map(Vector3(end_point.x, 0.0, end_point.y))
        draw_circle(mark, 6.0, Color("ffb454"))
    var colors := [Color("5aaaff"),Color("a2bb72"),Color("ff797d"),Color("edcc83")]
    var i := 0
    for poi in data.get("pois",[]):
        var point := _world_to_map(Vector3(poi[0],0,poi[1]))
        point = size*.5 + (point-size*.5).limit_length(size.x*.5-23)
        draw_circle(point,8,Color("0a1720"))
        draw_circle(point,7,colors[i % colors.size()])
        # Pontos de interesse continuam marcados por cor, sem textos sobre o mapa.
        i += 1
    for car in get_tree().get_nodes_in_group("vehicle"):
        var marker := _world_to_map(car.global_position)
        if Rect2(Vector2(7,7),size-Vector2(14,14)).has_point(marker):
            draw_rect(Rect2(marker-Vector2(3,4),Vector2(6,8)),Color("f4d686"))
    var center := size*0.5
    draw_circle(center,9,Color(0,0,0,0.6))
    draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(5,6),center+Vector2(0,3),center+Vector2(-5,6)]),Color("ffffff"))
    # O nome do bairro agora fica fora do círculo, abaixo do minimapa,
    # controlado pela HUD principal para não cobrir ruas/GPS.
    draw_arc(center,size.x*.5-3,0,TAU,96,Color("55e4bf"),2.0,true)
    draw_arc(center,size.x*.5-8,0,TAU,96,Color(.5,.8,.8,.18),1.0,true)

func _resize_circle() -> void:
    if material:
        material.set_shader_parameter("center",size*.5)
        material.set_shader_parameter("radius",minf(size.x,size.y)*.5)
    queue_redraw()

func _has_point(point: Vector2) -> bool:
    return point.distance_to(size*.5) <= minf(size.x,size.y)*.5

func _gui_input(event: InputEvent) -> void:
    if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
        pause_requested.emit()
        accept_event()

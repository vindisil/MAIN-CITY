extends Control
var spread: float = 0.0
var icon_kind: String = ""
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
    if icon_kind != "":
        _draw_action_icon()
        return
    var center := size * .5
    var gap: float = 4.0 + spread
    for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
        var start: Vector2 = center + direction * gap
        var finish: Vector2 = center + direction * (gap + 6.0)
        draw_line(start, finish, Color(0,0,0,.85), 3.0, true)
        draw_line(start, finish, Color(.94,1,1,.95), 1.3, true)
    draw_circle(center, 1.2, Color.WHITE)

func _draw_action_icon() -> void:
    var c := size * .5
    var r := minf(size.x,size.y) * .34
    var ink := Color(.90,.98,1,.95)
    draw_circle(c,r,Color(.02,.05,.08,.42))
    draw_arc(c,r,0,TAU,48,Color(.6,.9,1,.7),1.5,true)
    if icon_kind == "MIRAR":
        draw_arc(c,r*.48,0,TAU,32,ink,1.8,true)
        for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
            draw_line(c+direction*r*.28,c+direction*r*.70,ink,2.0,true)
    elif icon_kind == "ATIRAR":
        var points := PackedVector2Array([c+Vector2(-r*.20,r*.45),c+Vector2(-r*.20,-r*.20),c+Vector2(0,-r*.50),c+Vector2(r*.20,-r*.20),c+Vector2(r*.20,r*.45)])
        draw_colored_polygon(points,ink)
        draw_line(c+Vector2(-r*.29,r*.28),c+Vector2(r*.29,r*.28),Color(.15,.35,.45),2.0,true)
    else:
        draw_line(c+Vector2(0,r*.43),c-Vector2(0,r*.45),ink,2.5,true)
        draw_line(c-Vector2(0,r*.45),c+Vector2(-r*.35,-r*.10),ink,2.5,true)
        draw_line(c-Vector2(0,r*.45),c+Vector2(r*.35,-r*.10),ink,2.5,true)

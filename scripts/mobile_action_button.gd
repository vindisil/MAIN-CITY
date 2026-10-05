extends "res://scripts/multi_touch_button.gd"
## Icon-only controls. Artwork scales with the actual button/HUD size.
## Original action names remain available to saved layouts and the HUD editor.
const ICONS: Dictionary = {
    "ENTRAR": preload("res://assets/ui/mobile/enter.svg"),
    "SAIR": preload("res://assets/ui/mobile/exit.svg"),
    "ATIRAR": preload("res://assets/ui/mobile/fire.svg"),
    "MIRAR": preload("res://assets/ui/mobile/aim.svg"),
    "RECARGA": preload("res://assets/ui/mobile/reload.svg"),
    "PULAR": preload("res://assets/ui/mobile/jump.svg"),
    "CORRER": preload("res://assets/ui/mobile/run.svg"),
    "ABAIXAR": preload("res://assets/ui/mobile/crouch.svg"),
    "ROLAR": preload("res://assets/ui/mobile/roll.svg"),
    "USAR": preload("res://assets/ui/mobile/use.svg"),
    "ACELERADOR": preload("res://assets/ui/mobile/accelerate.svg"),
    "FREIO DE MÃO": preload("res://assets/ui/mobile/brake.svg"),
    "RÉ": preload("res://assets/ui/mobile/reverse.svg"),
    "◀": preload("res://assets/ui/mobile/steer_left.svg"),
    "▶": preload("res://assets/ui/mobile/steer_right.svg"),
    "ANTERIOR": preload("res://assets/ui/mobile/steer_left.svg"),
    "PROXIMA": preload("res://assets/ui/mobile/steer_right.svg"),
    "INVENTARIO": preload("res://assets/ui/mobile/inventory.svg"),
    "CONFIGURACOES": preload("res://assets/ui/mobile/settings.svg"),
    "LOJA": preload("res://assets/ui/mobile/shop.svg"),
    "CHAT_ABRIR": preload("res://assets/ui/mobile/chevron_up.svg"),
    "CHAT_FECHAR": preload("res://assets/ui/mobile/chevron_down.svg"),
    "PISTOLA": preload("res://assets/ui/mobile/pistol.svg"),
    "FUZIL": preload("res://assets/ui/mobile/rifle.svg"),
}
const NORMAL_BG := Color(0.025, 0.035, 0.045, 0.58)
const NORMAL_BORDER := Color(0.95, 0.98, 1.0, 0.55)
const NORMAL_INK := Color(0.96, 0.98, 1.0, 0.98)
const ACTIVE_BG := Color(0.035, 0.20, 0.17, 0.84)
const ACTIVE_BORDER := Color(0.33, 0.91, 0.74, 1.0)
const ACTIVE_INK := Color(0.80, 1.0, 0.94, 1.0)
var action_icon: Texture2D
var action_key: String = ""
var active_state: bool = false

func configure(key: String, label: String = "") -> void:
    action_key = key
    action_icon = ICONS.get(key) as Texture2D
    text = ""
    icon = null
    tooltip_text = label if not label.is_empty() else key.capitalize()
    set_meta("hud_label", key if label.is_empty() else label)
    set_meta("hud_icon_key", key)
    focus_mode = Control.FOCUS_NONE
    # Empty native styles keep the minimum touch size independent of text/fonts.
    for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
        add_theme_stylebox_override(state, StyleBoxEmpty.new())
    queue_redraw()

func _ready() -> void:
    super()
    resized.connect(queue_redraw)
    mouse_entered.connect(queue_redraw)
    mouse_exited.connect(queue_redraw)
    button_down.connect(_redraw_press)
    button_up.connect(queue_redraw)

func _redraw_press() -> void:
    # The inherited touch controller also styles older native buttons.
    modulate = Color.WHITE
    queue_redraw()

func set_active(value: bool) -> void:
    if active_state == value:
        return
    active_state = value
    queue_redraw()

func visual_pressed() -> bool:
    return active_finger >= 0 or get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED]

func _draw() -> void:
    var side: float = minf(size.x, size.y)
    if side <= 0.0:
        return
    var center := size * 0.5
    var radius := side * 0.46
    var highlighted := (active_state or visual_pressed()) and not disabled
    var background := ACTIVE_BG if highlighted else NORMAL_BG
    var border := ACTIVE_BORDER if highlighted else NORMAL_BORDER
    var ink := ACTIVE_INK if highlighted else NORMAL_INK
    if disabled:
        background.a = 0.35
        border.a = 0.22
        ink.a = 0.30
    elif get_draw_mode() == BaseButton.DRAW_HOVER:
        border.a = 0.90
    draw_circle(center + Vector2(0, 2), radius, Color(0, 0, 0, 0.22))
    draw_circle(center, radius, background)
    draw_arc(center, radius, 0, TAU, 64, border, maxf(1.5, side * 0.016), true)
    if action_icon != null:
        var icon_side := side * 0.74
        var icon_rect := Rect2(center - Vector2.ONE * icon_side * 0.5, Vector2.ONE * icon_side)
        draw_texture_rect(action_icon, icon_rect, false, ink)

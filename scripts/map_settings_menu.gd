extends CanvasLayer
## BR1 v0.5.24 - mapa separado, configuracoes em lista lateral e HUD moderno.

const ACCENT := Color("55e4bf")
const MUTED := Color("9aafc8")
const PANEL_BG := Color(0.025,0.055,0.085,0.88)
const PANEL_BG_SOFT := Color(0.035,0.075,0.11,0.72)
const LINE := Color(0.36,0.72,0.82,0.30)
const CHARACTER_FOV_LEVELS := [58.0,60.0,62.0,64.0,66.0]
const VEHICLE_FOV_LEVELS := [66.0,68.0,70.0,72.0,74.0]
const HUD_LAYOUT_VERSION: int = 48
const WEAPONS = preload("res://scripts/tps_weapons.gd")
const MobileActionButtonScript = preload("res://scripts/mobile_action_button.gd")

var p: Node
var root: Control
var overlay: ColorRect
var panel: PanelContainer
var panel_column: VBoxContainer
var header: HBoxContainer
var page_title: Label
var body_host: MarginContainer
var note: Label
var gps_map: Control
var navigation: Variant = null
var gps_status: Label
var gps_clock: float = 0.0
var backpack_button: Button
var settings_button: Button
var menu_open: bool = false
var tab: int = 1
var settings_category: int = 0
var quality: int = 0
var controls: int = 0
var steering_mode: int = 0
var hud_button_scale: float = 1.20
var hud_positions: Dictionary = {}
var character_fov: float = 62.0
var vehicle_fov: float = 70.0
var settings_category_buttons: Array[Button] = []

static func _panel_style(bg: Color, border: Color = LINE, radius: int = 10, margin: int = 14) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1)
    s.set_corner_radius_all(radius)
    s.content_margin_left = margin
    s.content_margin_right = margin
    s.content_margin_top = margin
    s.content_margin_bottom = margin
    return s

func button(title: String, compact: bool = false) -> Button:
    var b := Button.new()
    b.text = title
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size = Vector2(52 if compact else 128, 48 if compact else 52)
    b.add_theme_font_size_override("font_size",15 if compact else 16)
    b.add_theme_stylebox_override("normal",_panel_style(Color(0.03,0.07,0.105,0.56),LINE,8,10))
    b.add_theme_stylebox_override("hover",_panel_style(Color(0.06,0.13,0.17,0.72),Color(0.42,0.90,0.82,0.56),8,10))
    b.add_theme_stylebox_override("pressed",_panel_style(Color(0.05,0.22,0.18,0.74),ACCENT,8,10))
    b.add_theme_stylebox_override("focus",_panel_style(Color(0.03,0.07,0.105,0.56),ACCENT,8,10))
    b.add_theme_color_override("font_hover_color",ACCENT)
    return b

func label(title: String, size: int, color: Color = Color.WHITE) -> Label:
    var l := Label.new()
    l.text = title
    l.add_theme_font_size_override("font_size",size)
    l.add_theme_color_override("font_color",color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func box(horizontal: bool = false, separation: int = 12) -> BoxContainer:
    var b: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
    b.add_theme_constant_override("separation",separation)
    return b

func place(c: Control, anchor: Vector2, pos: Vector2, dimensions: Vector2) -> void:
    c.anchor_left = anchor.x
    c.anchor_right = anchor.x
    c.anchor_top = anchor.y
    c.anchor_bottom = anchor.y
    c.offset_left = pos.x
    c.offset_top = pos.y
    c.offset_right = pos.x + dimensions.x
    c.offset_bottom = pos.y + dimensions.y

func setup(player: Node) -> void:
    p = player
    navigation = p.get_parent().get_node_or_null("GPSNavigation")
    layer = 60
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()

    root = Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root)

    backpack_button = _floating_square("INVENTARIO","Inventário")
    root.add_child(backpack_button)
    backpack_button.pressed.connect(open_page.bind(0))

    settings_button = _floating_square("CONFIGURACOES","Configurações")
    root.add_child(settings_button)
    settings_button.pressed.connect(open_page.bind(2))

    overlay = ColorRect.new()
    overlay.color = Color(0.008,0.018,0.03,0.58)
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.hide()
    root.add_child(overlay)

    panel = PanelContainer.new()
    panel.add_theme_stylebox_override("panel",_panel_style(PANEL_BG,Color(0.42,0.78,0.84,0.34),12,18))
    overlay.add_child(panel)

    panel_column = box(false,10)
    panel.add_child(panel_column)

    header = box(true,12) as HBoxContainer
    panel_column.add_child(header)
    var titles := box(false,1)
    titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(titles)
    titles.add_child(label("MAIN CITY",11,ACCENT))
    page_title = label("Configurações",28)
    titles.add_child(page_title)
    var close := button("×",true)
    close.custom_minimum_size = Vector2(48,48)
    close.tooltip_text = "Fechar"
    close.add_theme_font_size_override("font_size",24)
    header.add_child(close)
    close.pressed.connect(func(): set_menu(false))

    body_host = MarginContainer.new()
    body_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel_column.add_child(body_host)

    note = label("",13,MUTED)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel_column.add_child(note)

    gps_status = label("",14,ACCENT)
    gps_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    gps_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(gps_status)

    get_viewport().size_changed.connect(layout)
    call_deferred("apply_quality")
    call_deferred("layout")
    set_process(true)

func _floating_square(icon: String, tooltip: String) -> Button:
    var b := MobileActionButtonScript.new()
    b.configure(icon, tooltip)
    b.custom_minimum_size = Vector2(50,50)
    return b

func layout() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var dim := Vector2(minf(1060.0,viewport_size.x-36.0),minf(650.0,viewport_size.y-30.0))
    place(panel,Vector2(.5,.5),-dim*.5,dim)
    place(backpack_button,Vector2.ZERO,Vector2(74,230),Vector2(50,50))
    place(settings_button,Vector2.ZERO,Vector2(132,230),Vector2(50,50))
    place(gps_status,Vector2(.5,1.0),Vector2(-190,-72),Vector2(380,24))
    _apply_controls_mode()
    _apply_hud_scale()

func open_page(index: int) -> void:
    tab = clampi(index,0,3)
    set_menu(true)

func open_shop() -> void:
    open_page(3)

func set_menu(open: bool) -> void:
    if open and p.has_method("cancel_combat_input"):
        p.call("cancel_combat_input")
    menu_open = open
    overlay.visible = open
    get_tree().paused = open
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    if open:
        show_tab(tab)
    else:
        save_settings()
        _apply_controls_mode()
        call_deferred("_apply_controls_mode")

func _clear_body() -> void:
    for child in body_host.get_children():
        body_host.remove_child(child)
        child.queue_free()
    gps_map = null

func show_tab(index: int) -> void:
    tab = clampi(index,0,3)
    _clear_body()
    header.visible = tab != 1
    note.visible = tab != 1

    if tab == 0:
        page_title.text = "Inventário"
        _build_inventory_page()
    elif tab == 1:
        _build_map_page()
    elif tab == 2:
        page_title.text = "Configurações"
        _build_settings_page()
    else:
        page_title.text = "Loja"
        _build_shop_page()

func _build_inventory_page() -> void:
    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body_host.add_child(scroll)
    var list := box(false,10)
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    list.add_child(label("INVENTÁRIO",13,ACCENT))
    _inventory_entry(list,"MÃOS LIVRES","Guardar a arma atual.",-1)
    for index in range(WEAPONS.NAMES.size()):
        var description := "Equipar a pistola do Third Person Shooter." if WEAPONS.ANIMATION_KIND[index] == 1 else "Equipar o fuzil " + WEAPONS.NAMES[index] + "."
        _inventory_entry(list, WEAPONS.NAMES[index], description, index)
    note.text = "Escolha o que deseja carregar nas mãos."

func _build_map_page() -> void:
    var map_row := box(true,14)
    map_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_host.add_child(map_row)

    var map_frame := PanelContainer.new()
    map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    map_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    map_frame.add_theme_stylebox_override("panel",_panel_style(Color(0.018,0.045,0.067,0.74),Color(0.35,0.76,0.80,0.28),8,8))
    map_row.add_child(map_frame)
    var new_map: Control = load("res://scripts/pause_city_map.gd").new() as Control
    new_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    new_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
    new_map.custom_minimum_size = Vector2(480,430)
    map_frame.add_child(new_map)
    gps_map = new_map
    new_map.destination_selected.connect(_select_gps_destination)

    var legend_frame := PanelContainer.new()
    legend_frame.custom_minimum_size = Vector2(245,0)
    legend_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    legend_frame.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.065,0.09,0.72),Color(0.45,0.82,0.86,0.28),8,16))
    map_row.add_child(legend_frame)
    var legend := box(false,10)
    legend_frame.add_child(legend)
    var legend_top := box(true,8)
    legend.add_child(legend_top)
    var legend_titles := box(false,1)
    legend_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    legend_top.add_child(legend_titles)
    legend_titles.add_child(label("MAPA / GPS",18))
    legend_titles.add_child(label("Legenda",12,ACCENT))
    var close := button("×",true)
    close.custom_minimum_size = Vector2(42,42)
    close.add_theme_font_size_override("font_size",22)
    close.pressed.connect(func(): set_menu(false))
    legend_top.add_child(close)
    _legend_item(legend,Color("637f94"),"Construções")
    _legend_item(legend,Color("233e51"),"Ruas")
    _legend_item(legend,Color("4decc0"),"Rota GPS")
    _legend_item(legend,Color("ffb454"),"Destino marcado")
    _legend_item(legend,Color("ffffff"),"Sua posição")
    _legend_item(legend,Color("57bba9"),"Limite do mapa")
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    legend.add_child(spacer)
    var hint := label("Toque no mapa para marcar um destino.",12,MUTED)
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    legend.add_child(hint)
    var clear := button("REMOVER ROTA")
    clear.pressed.connect(_clear_gps_destination)
    legend.add_child(clear)
    var route_status := label("",12,ACCENT)
    route_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    legend.add_child(route_status)
    if navigation != null and navigation.has_destination:
        route_status.text = "Destino ativo • %d m restantes" % roundi(navigation.remaining_distance())
    else:
        route_status.text = "Nenhuma rota ativa"

func _legend_item(parent: VBoxContainer, color: Color, text: String) -> void:
    var row := box(true,10)
    parent.add_child(row)
    var mark := ColorRect.new()
    mark.color = color
    mark.custom_minimum_size = Vector2(18,18)
    mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(mark)
    var name := label(text,13,Color(0.90,0.96,0.98,1.0))
    name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(name)

func _build_settings_page() -> void:
    var frame := box(true,14)
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_host.add_child(frame)

    var categories_panel := PanelContainer.new()
    categories_panel.custom_minimum_size = Vector2(215,0)
    categories_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    categories_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.06,0.09,0.64),Color(0.40,0.75,0.82,0.24),8,10))
    frame.add_child(categories_panel)
    var categories := box(false,8)
    categories_panel.add_child(categories)
    categories.add_child(label("CATEGORIAS",11,ACCENT))
    settings_category_buttons.clear()
    var names := ["GRÁFICOS","CONTROLES","HUD","CÂMERA"]
    for i in range(names.size()):
        var category_button := button(names[i])
        category_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
        category_button.pressed.connect(_select_settings_category.bind(i))
        categories.add_child(category_button)
        settings_category_buttons.append(category_button)
    var cat_spacer := Control.new()
    cat_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    categories.add_child(cat_spacer)
    categories.add_child(label("Ajustes são salvos automaticamente.",11,MUTED))

    var functions_panel := PanelContainer.new()
    functions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    functions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    functions_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.055,0.08,0.50),Color(0.36,0.68,0.76,0.20),8,12))
    frame.add_child(functions_panel)
    var scroll := ScrollContainer.new()
    scroll.name = "SettingsScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    functions_panel.add_child(scroll)
    var list := box(false,12)
    list.name = "SettingsFunctions"
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(list)
    _populate_settings_category(list)
    _refresh_category_buttons()
    note.text = "Configurações organizadas por categoria • M / Esc para fechar"

func _select_settings_category(index: int) -> void:
    settings_category = clampi(index,0,3)
    show_tab(2)

func _refresh_category_buttons() -> void:
    for i in range(settings_category_buttons.size()):
        var active := i == settings_category
        settings_category_buttons[i].modulate = Color.WHITE
        settings_category_buttons[i].add_theme_color_override("font_color",ACCENT if active else Color(0.90,0.95,0.98))
        if active:
            settings_category_buttons[i].add_theme_stylebox_override("normal",_panel_style(Color(0.04,0.18,0.16,0.58),ACCENT,8,10))

func _populate_settings_category(list: VBoxContainer) -> void:
    if settings_category == 0:
        list.add_child(label("GRÁFICOS",18,ACCENT))
        _option_into(list,"Qualidade gráfica","Define o equilíbrio entre desempenho e qualidade visual.",["Automático","Leve · 30 FPS","Equilibrado · 60 FPS","Alto · 60 FPS"],quality,func(i):
            quality=i
            apply_quality()
            save_settings()
        )
        list.add_child(_help_card("O perfil Leve reduz resolução 3D, sombras e distância de detalhes para celulares básicos."))
    elif settings_category == 1:
        list.add_child(label("CONTROLES",18,ACCENT))
        _option_into(list,"Tipo de controle","Escolha o esquema de entrada usado pelo jogo.",["Automático","Toque / celular","Teclado e mouse"],controls,func(i):
            controls=i
            _apply_controls_mode()
            _apply_hud_scale()
            save_settings()
        )
        _option_into(list,"Direção de veículos","Troque entre setas e analógico para dirigir.",["Botões ◀ ▶","Analógico"],steering_mode,func(i):
            steering_mode=i
            _apply_vehicle_settings()
            save_settings()
        )
    elif settings_category == 2:
        list.add_child(label("HUD",18,ACCENT))
        _option_into(list,"Tamanho dos botões","Altera somente o tamanho, preservando as posições salvas.",["Pequeno","Médio","Grande"],_hud_scale_index(),func(i):
            hud_button_scale=[0.95,1.20,1.55][i]
            _apply_hud_scale()
            save_settings()
        )
        var edit_card := PanelContainer.new()
        edit_card.add_theme_stylebox_override("panel",_panel_style(PANEL_BG_SOFT,LINE,8,12))
        list.add_child(edit_card)
        var edit_row := box(true,12)
        edit_card.add_child(edit_row)
        var edit_text := box(false,2)
        edit_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        edit_row.add_child(edit_text)
        edit_text.add_child(label("Editor da HUD",16))
        edit_text.add_child(label("Arraste os controles e salve a posição. Funciona também dentro do veículo.",12,MUTED))
        var edit := button("EDITAR HUD")
        edit.pressed.connect(begin_hud_edit)
        edit_row.add_child(edit)
    else:
        list.add_child(label("CÂMERA",18,ACCENT))
        _option_into(list,"FOV do personagem","Pequena faixa de ajuste da câmera a pé.",["58 · Mais perto","60 · Perto","62 · Padrão","64 · Aberto","66 · Mais aberto"],_nearest_level(character_fov,CHARACTER_FOV_LEVELS),func(i):
            character_fov=float(CHARACTER_FOV_LEVELS[i])
            if p.has_method("set_character_fov"):
                p.call("set_character_fov",character_fov)
            save_settings()
        )
        _option_into(list,"FOV dos veículos","Pequena faixa de ajuste da câmera externa.",["66 · Mais perto","68 · Perto","70 · Padrão","72 · Aberto","74 · Mais aberto"],_nearest_level(vehicle_fov,VEHICLE_FOV_LEVELS),func(i):
            vehicle_fov=float(VEHICLE_FOV_LEVELS[i])
            if p.has_method("set_vehicle_fov"):
                p.call("set_vehicle_fov",vehicle_fov)
            save_settings()
        )
        var sensitivity_card := PanelContainer.new()
        sensitivity_card.add_theme_stylebox_override("panel",_panel_style(PANEL_BG_SOFT,LINE,8,12))
        list.add_child(sensitivity_card)
        var sensitivity_box := box(false,6)
        sensitivity_card.add_child(sensitivity_box)
        sensitivity_box.add_child(label("Sensibilidade da câmera",16))
        sensitivity_box.add_child(label("Ajuste fino para mouse e toque.",12,MUTED))
        var slider := HSlider.new()
        slider.min_value = .001
        slider.max_value = .007
        slider.step = .0001
        slider.value = p.mouse_sensitivity
        slider.custom_minimum_size.y = 42
        sensitivity_box.add_child(slider)
        slider.value_changed.connect(func(v):
            p.mouse_sensitivity=v
            p.touch_sensitivity=v*1.5
            save_settings()
        )

func _option_into(parent: VBoxContainer, title: String, detail: String, options: Array, selected: int, callback: Callable) -> void:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",_panel_style(PANEL_BG_SOFT,LINE,8,12))
    parent.add_child(card)
    var row := box(true,14)
    card.add_child(row)
    var texts := box(false,2)
    texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(texts)
    texts.add_child(label(title,16))
    var desc := label(detail,12,MUTED)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    texts.add_child(desc)
    var select := OptionButton.new()
    select.custom_minimum_size = Vector2(230,46)
    select.add_theme_stylebox_override("normal",_panel_style(Color(0.02,0.07,0.10,0.66),LINE,7,10))
    select.add_theme_stylebox_override("hover",_panel_style(Color(0.04,0.12,0.15,0.74),ACCENT,7,10))
    select.add_theme_font_size_override("font_size",14)
    for text_value in options:
        select.add_item(str(text_value))
    select.select(clampi(selected,0,maxi(0,options.size()-1)))
    select.item_selected.connect(callback)
    row.add_child(select)

func _help_card(text_value: String) -> PanelContainer:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.07,0.09,0.44),Color(0.35,0.68,0.74,0.18),8,12))
    var txt := label(text_value,12,MUTED)
    txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.add_child(txt)
    return card

func _build_shop_page() -> void:
    var body := box(false,12)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body_host.add_child(body)
    body.add_child(label("LOJA MAIN CITY",18,ACCENT))
    body.add_child(label("Carteira",13,MUTED))
    var wallet := box(true,12)
    body.add_child(wallet)
    var state: Node = p.get("game_state") as Node
    var money_value: int = int(state.get("money")) if state != null else 0
    var coins_value: int = int(state.get("main_coins")) if state != null else 0
    wallet.add_child(_wallet_card("DINHEIRO","R$ %d" % money_value))
    wallet.add_child(_wallet_card("MAIN COINS","MC %d" % coins_value))
    body.add_child(_help_card("O botão da loja e a moeda Main Coins já estão preparados. Os itens e pacotes podem ser adicionados depois sem misturar a loja com as configurações."))
    var spacer := Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_child(spacer)
    note.text = "Main Coins é a moeda virtual paga do Main City."

func _wallet_card(title: String, value: String) -> PanelContainer:
    var card := PanelContainer.new()
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_theme_stylebox_override("panel",_panel_style(Color(0.02,0.065,0.09,0.58),Color(0.48,0.82,0.82,0.26),8,16))
    var col := box(false,2)
    card.add_child(col)
    col.add_child(label(title,11,MUTED))
    col.add_child(label(value,22,ACCENT))
    return card

func _inventory_entry(parent: VBoxContainer, title: String, detail: String, weapon_index: int) -> void:
    var card := PanelContainer.new()
    card.add_theme_stylebox_override("panel",_panel_style(PANEL_BG_SOFT,LINE,8,12))
    parent.add_child(card)
    var row := box(true,12)
    card.add_child(row)
    var texts := box(false,2)
    texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(texts)
    texts.add_child(label(title,17))
    var desc := label(detail,12,MUTED)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    texts.add_child(desc)
    var equipped: bool = int(p.get("selected_weapon")) == weapon_index
    var action := button("EQUIPADA" if equipped else "EQUIPAR")
    action.disabled = equipped
    action.pressed.connect(_equip_inventory.bind(weapon_index))
    row.add_child(action)

func _equip_inventory(index: int) -> void:
    if p.get("vehicle") != null:
        return
    p.call("_select_weapon",index)
    set_menu(false)

func _input(event: InputEvent) -> void:
    if bool(get_tree().get_meta("br1_chat_typing",false)):
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode in [KEY_ESCAPE,KEY_M]:
            if menu_open:
                set_menu(false)
            else:
                open_page(1)
            get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    gps_clock += delta
    if gps_clock < 0.5 or gps_status == null:
        return
    gps_clock = 0.0
    if navigation != null and navigation.has_destination and not menu_open:
        gps_status.text = "GPS  |  %d m até o destino" % roundi(navigation.remaining_distance())
        gps_status.visible = true
    else:
        gps_status.visible = false

func _select_gps_destination(world_location: Vector2) -> void:
    if navigation == null:
        return
    navigation.set_destination(world_location)
    if is_instance_valid(gps_map):
        gps_map.queue_redraw()

func _clear_gps_destination() -> void:
    if navigation != null:
        navigation.clear_destination()
    if is_instance_valid(gps_map):
        gps_map.queue_redraw()
    if tab == 1 and menu_open:
        show_tab(1)

func _nearest_level(value: float, levels: Array) -> int:
    var best_index: int = 0
    var best_distance: float = INF
    for i in range(levels.size()):
        var distance: float = absf(float(levels[i])-value)
        if distance < best_distance:
            best_distance = distance
            best_index = i
    return best_index

func _hud_scale_index() -> int:
    if hud_button_scale >= 1.55:
        return 2
    if hud_button_scale >= 1.20:
        return 1
    return 0

func _apply_controls_mode() -> void:
    var mobile: bool = (OS.has_feature("mobile") or p.force_touch_ui_on_desktop) if controls == 0 else controls == 1
    if p.has_method("set_mobile_controls_enabled"):
        p.call("set_mobile_controls_enabled",mobile)
    else:
        p.touch_ui_enabled = mobile

func _apply_hud_scale() -> void:
    if p == null or p.touch_root == null:
        return
    for button_node in p.touch_root.find_children("*","Button",true,false):
        var control := button_node as Control
        if control == null:
            continue
        if not control.has_meta("base_rect"):
            control.set_meta("base_rect",Rect2(control.position,control.size))
        var base: Rect2 = control.get_meta("base_rect")
        var center_before: Vector2 = control.get_global_rect().get_center()
        var new_size := base.size * hud_button_scale
        control.size = new_size
        control.pivot_offset = new_size * 0.5
        control.position += center_before-control.get_global_rect().get_center()
        if button_node is Button:
            var b := button_node as Button
            var base_font: int = int(b.get_meta("base_font_size",b.get_theme_font_size("font_size")))
            b.add_theme_font_size_override("font_size",int(round(base_font*hud_button_scale)))
    _apply_vehicle_settings()
    _apply_saved_hud_positions()

func _apply_saved_hud_positions() -> void:
    if hud_positions.is_empty():
        if p.touch_ui_enabled and p.has_method("_clamp_mobile_controls_to_screen"):
            p.call_deferred("_clamp_mobile_controls_to_screen")
        return
    var items := _hud_items()
    var screen := get_viewport().get_visible_rect().size
    if screen.x <= 0.0 or screen.y <= 0.0:
        return
    for key in items:
        if not hud_positions.has(key):
            continue
        var control := items[key] as Control
        if control == null or not is_instance_valid(control):
            continue
        var normalized: Vector2 = hud_positions[key]
        var half := control.size*0.5
        var desired_center := normalized*screen
        desired_center.x = clampf(desired_center.x,half.x+8.0,screen.x-half.x-8.0)
        desired_center.y = clampf(desired_center.y,half.y+8.0,screen.y-half.y-8.0)
        control.position += desired_center-control.get_global_rect().get_center()
    if p.touch_ui_enabled and p.has_method("_clamp_mobile_controls_to_screen"):
        p.call_deferred("_clamp_mobile_controls_to_screen")

func _apply_vehicle_settings() -> void:
    for car in get_tree().get_nodes_in_group("vehicle"):
        if not is_instance_valid(car):
            continue
        if car.has_method("set_mobile_ui_enabled"):
            car.call("set_mobile_ui_enabled",p.touch_ui_enabled)
        if car.has_method("set_mobile_steering_mode"):
            car.call("set_mobile_steering_mode",steering_mode)
        if car.has_method("set_user_camera_fov"):
            car.call("set_user_camera_fov",vehicle_fov)
        for b in car.find_children("*","Button",true,false):
            if not str(b.name).begins_with("HUD_"):
                continue
            if str(b.name) in ["HUD_Edit","HUD_Camera"]:
                b.visible = false
                continue
            b.visible = p.touch_ui_enabled
            if not b.has_meta("base_rect"):
                b.set_meta("base_rect",Rect2(b.position,b.size))
            var base: Rect2 = b.get_meta("base_rect")
            var center_before: Vector2 = b.get_global_rect().get_center()
            var new_size := base.size * hud_button_scale
            b.size = new_size
            b.pivot_offset = new_size*0.5
            b.position += center_before-b.get_global_rect().get_center()
            if b is Button:
                var vehicle_button := b as Button
                var base_font: int = int(vehicle_button.get_meta("base_font_size",vehicle_button.get_theme_font_size("font_size")))
                vehicle_button.add_theme_font_size_override("font_size",int(round(base_font*hud_button_scale)))
        if car.has_method("apply_saved_hud_positions"):
            car.call("apply_saved_hud_positions",hud_positions)

func _hud_items() -> Dictionary:
    if p.vehicle != null and is_instance_valid(p.vehicle) and p.vehicle.has_method("get_hud_items"):
        var vehicle_items: Variant = p.vehicle.call("get_hud_items")
        if vehicle_items is Dictionary:
            vehicle_items.erase("HUD_Edit")
            vehicle_items.erase("HUD_Camera")
            return vehicle_items
    var result: Dictionary = {}
    for b in p.touch_root.find_children("*","Button",true,false):
        result["toque_"+str(b.get_meta("hud_label",b.text)).to_lower()] = b
    if p.joystick != null:
        result["movimento"] = p.joystick
    return result

func begin_hud_edit() -> void:
    if menu_open:
        set_menu(false)
    var items := _hud_items()
    get_tree().paused = true
    var layer_edit := CanvasLayer.new()
    layer_edit.name = "HUDEditorLayer"
    layer_edit.layer = 110
    layer_edit.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(layer_edit)
    var editor := Control.new()
    editor.set_script(preload("res://scripts/hud_editor.gd"))
    layer_edit.add_child(editor)
    editor.call("configure",items)
    editor.connect("finished",func(save_changes: bool, positions: Dictionary):
        if save_changes:
            var screen := get_viewport().get_visible_rect().size
            for key in positions:
                var node := items.get(key) as Control
                if node != null:
                    var center := node.get_global_rect().get_center()
                    hud_positions[key] = Vector2(center.x/maxf(screen.x,1.0),center.y/maxf(screen.y,1.0))
            save_settings()
        layer_edit.queue_free()
        get_tree().paused = false
        call_deferred("_apply_hud_scale")
    )

func load_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://personal_v013.cfg") != OK:
        return
    quality = clampi(int(config.get_value("settings","quality",0)),0,3)
    controls = clampi(int(config.get_value("settings","controls",0)),0,2)
    steering_mode = clampi(int(config.get_value("settings","steering_mode",0)),0,1)
    hud_button_scale = clampf(float(config.get_value("settings","hud_button_scale",1.20)),0.95,1.55)
    character_fov = clampf(float(config.get_value("settings","character_fov",62.0)),58.0,66.0)
    vehicle_fov = clampf(float(config.get_value("settings","vehicle_fov",70.0)),66.0,74.0)
    settings_category = clampi(int(config.get_value("settings","settings_category",0)),0,3)
    if p.has_method("set_character_fov"):
        p.call("set_character_fov",character_fov)
    if p.has_method("set_vehicle_fov"):
        p.call("set_vehicle_fov",vehicle_fov)
    var saved_layout_version: int = int(config.get_value("settings","hud_layout_version",0))
    hud_positions = config.get_value("settings","hud_positions",{}) if saved_layout_version == HUD_LAYOUT_VERSION else {}
    p.mouse_sensitivity = clampf(float(config.get_value("settings","sensitivity",.0027)),.001,.007)
    p.touch_sensitivity = p.mouse_sensitivity*1.5

func save_settings() -> void:
    var config := ConfigFile.new()
    config.set_value("settings","quality",quality)
    config.set_value("settings","controls",controls)
    config.set_value("settings","steering_mode",steering_mode)
    config.set_value("settings","hud_button_scale",hud_button_scale)
    config.set_value("settings","character_fov",character_fov)
    config.set_value("settings","vehicle_fov",vehicle_fov)
    config.set_value("settings","settings_category",settings_category)
    config.set_value("settings","hud_positions",hud_positions)
    config.set_value("settings","hud_layout_version",HUD_LAYOUT_VERSION)
    config.set_value("settings","sensitivity",p.mouse_sensitivity)
    config.save("user://personal_v013.cfg")

func apply_quality() -> void:
    var level: int = (1 if OS.has_feature("mobile") else 2) if quality == 0 else quality
    get_viewport().scaling_3d_scale = [1.0,.72,.88,1.0][level]

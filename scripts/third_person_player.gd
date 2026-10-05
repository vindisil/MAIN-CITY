extends CharacterBody3D
## Main City - controlador do Third Person Shooter adaptado para Godot 4.6.
## Animacoes/esqueleto/armas do pacote original; integracao de HUD, chat e veiculos.
const GameStateScript = preload("res://scripts/game_state.gd")
const MiniMapScript = preload("res://scripts/minimap.gd")
const TextChatScript = preload("res://scripts/text_chat.gd")
const VirtualJoystickScript = preload("res://scripts/virtual_joystick.gd")
const MobileActionButtonScript = preload("res://scripts/mobile_action_button.gd")
const MapSettingsMenuScript = preload("res://scripts/map_settings_menu.gd")

const GUN_SOUNDS = [
    preload("res://assets/third_person_shooter/Rifle_fire.wav"),
    preload("res://assets/third_person_shooter/Pistol_fire.wav")
]
const RELOAD_SOUNDS = [
    preload("res://assets/third_person_shooter/Rifle_reload.wav"),
    preload("res://assets/third_person_shooter/Pistol_reload.wav")
]
const EMPTY_SOUND = preload("res://assets/audio/empty.wav")
const ShotEffects = preload("res://scripts/shot_effects.gd")
const WEAPONS = preload("res://scripts/tps_weapons.gd")
var shot_effects: Node3D
var muzzle_flash: MeshInstance3D
var muzzle_time: float = 0.0
var muzzle_flash_frame: int = -1
var camera_recoil: float = 0.0

const WEAPON_NAMES: Array[String] = WEAPONS.NAMES

var game_state: Node = null
var visual: Node3D = null
var weapon_rig: Node3D = null
var weapon_nodes: Array[Node3D] = []
var weapon_muzzles: Array[Marker3D] = []
var weapon_flashes: Array[MeshInstance3D] = []
var selected_weapon: int = -1

# Compatibilidade minima com sistemas do mapa que apenas consultam o Player.
var vehicle: Node = null
var in_vehicle_mode: bool = false
var vehicle_exit_callback: Callable
var modern_ui: CanvasLayer = null
var brasilia_clock: Label = null
var health: float = 100.0
var armor: float = 100.0

# V0.4.2 - HUD minimo restaurado. Nao controla animacoes.
var hud_layer: CanvasLayer = null
var hud_root: Control = null
var touch_root: Control = null
var minimap: Control = null
var text_chat: Control = null
var health_bar: ProgressBar = null
var armor_bar: ProgressBar = null
var health_text: Label = null
var armor_text: Label = null
var enter_vehicle_button: Button = null
var map_settings_menu: CanvasLayer = null
var touch_buttons: Dictionary = {}
var collision_shape: CollisionShape3D = null
var nearby_vehicle: Node3D = null
var vehicle_scan_clock: float = 0.0
var weapon_buttons: Array[Button] = []
var weapon_hud: PanelContainer = null
var weapon_hud_icon: TextureRect = null
var weapon_hud_name: Label = null
var weapon_prev_button: Button = null
var weapon_next_button: Button = null
var store_button: Button = null
var money_panel: PanelContainer = null
var money_label: Label = null
var coins_panel: PanelContainer = null
var main_coins_label: Label = null

var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var cam_yaw: float = 0.0
var cam_pitch: float = deg_to_rad(-12.0)
var camera_dragging: bool = false
var joystick: Control
var touch_sprint: bool = false
# Entrada compartilhada com a nova arvore de animacao TPS.
var input_dir: Vector2 = Vector2.ZERO
var input_strength: float = 0.0
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false
var touch_look_index: int = -1
const WALK_SPEED: float = 2.2
const RUN_SPEED: float = 5.0
const ACCELERATION: float = 5.0
const DECELERATION: float = 5.0
const TURN_RESPONSE_WALK: float = 7.8
const TURN_RESPONSE_RUN: float = 9.6
@export var force_touch_ui_on_desktop: bool = false
@export var mouse_sensitivity: float = 0.0027
@export var touch_sensitivity: float = 0.0042
var touch_ui_enabled: bool = false

# V0.5.2 - sistema de tiro confiável por raycast.
const FIRE_RATES: Array[float] = WEAPONS.FIRE_RATES
const WEAPON_DAMAGE: Array[float] = WEAPONS.DAMAGE
const WEAPON_RANGE: float = 900.0
const MAGAZINE_SIZE: Array[int] = WEAPONS.MAGAZINE
const RELOAD_TIME: Array[float] = WEAPONS.RELOAD_TIME
const IMPACT_IMPULSE: Array[float] = WEAPONS.IMPULSE
const WEAPON_AUTOMATIC: Array[bool] = WEAPONS.AUTOMATIC
# Tempos derivados de weapon_switch_rifle/pistol do pacote fonte.
const WEAPON_SWITCH_TIME: Array[float] = WEAPONS.SWITCH_TIME

var magazine_ammo: Array[int] = WEAPONS.MAGAZINE.duplicate()
var reserve_ammo: Array[int] = WEAPONS.RESERVE.duplicate()
var crouching: bool = false
var roll_remaining: float = 0.0
var roll_direction := Vector3.ZERO
var fire_pose_remaining: float = 0.0
var fire_held: bool = false
var fire_press_pending: bool = false
var semi_auto_pending: bool = false
var aiming: bool = false
var fire_cooldown: float = 0.0
var reload_remaining: float = 0.0
var reloading_weapon: int = -1
var weapon_switch_remaining: float = 0.0
var weapon_switch_duration: float = 0.0
var gun_audio: AudioStreamPlayer3D = null
var reload_audio: AudioStreamPlayer3D = null
var aim_reticle: Control = null
var fire_button_ref: Button = null
var aim_button_ref: Button = null
var reload_button_ref: Button = null
var aim_trigger_held: bool = false
var camera_aim_weight: float = 0.0
var free_camera_distance: float = 5.35
var character_fov: float = 62.0
var vehicle_fov: float = 70.0
var jump_buffer: float = 0.0
var coyote_time: float = 0.0
var landing_weight: float = 0.0
const JUMP_SPEED: float = 15.0
const MAX_SHOTS_PER_TICK: int = 3
const DAMAGE_METHODS: Array[StringName] = [&"take_damage", &"apply_damage", &"damage", &"hit"]
var camera_shot_query := PhysicsRayQueryParameters3D.new()
var muzzle_shot_query := PhysicsRayQueryParameters3D.new()
var damage_method_cache: Dictionary = {}

func _ready() -> void:
    shot_effects = ShotEffects.new()
    add_child(shot_effects)
    game_state = get_node_or_null("/root/GameState")
    if game_state == null:
        game_state = GameStateScript.new()
        game_state.name = "GameState"
        get_tree().root.add_child(game_state)

    if String(game_state.get("selected_gender")) not in ["masculino", "feminino"]:
        set_physics_process(false)
        set_process_input(false)
        get_tree().call_deferred("change_scene_to_file", "res://scenes/gender_select.tscn")
        return

    visual = get_node_or_null("Visual") as Node3D
    weapon_rig = visual.weapon_rig if visual != null else null
    camera_pivot = get_node_or_null("CameraPivot") as Node3D
    spring_arm = get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
    camera = get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D
    collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
    _sync_character_collider_to_ground()

    gun_audio = AudioStreamPlayer3D.new()
    gun_audio.name = "GunAudio"
    gun_audio.max_distance = 115.0
    gun_audio.volume_db = -6.0
    gun_audio.max_polyphony = 4
    add_child(gun_audio)

    reload_audio = AudioStreamPlayer3D.new()
    reload_audio.name = "ReloadAudio"
    reload_audio.max_distance = 35.0
    reload_audio.volume_db = -10.0
    add_child(reload_audio)

    if visual != null:
        visual.rotation.y = PI

    if visual != null:
        weapon_nodes.assign(visual.weapon_nodes)
        weapon_muzzles.assign(visual.weapon_muzzles)
        weapon_flashes.assign(visual.weapon_flashes)
        _select_weapon(0)

    for query in [camera_shot_query, muzzle_shot_query]:
        query.collide_with_bodies = true
        query.collide_with_areas = true
        query.hit_from_inside = true
        query.exclude = [get_rid()]

    if camera != null:
        camera.current = true
        camera.near = 0.035
        camera.far = 1500.0
        camera.fov = character_fov
    if camera_pivot != null:
        camera_pivot.position = Vector3(0.0, 1.4651, 0.0)
    if spring_arm != null:
        spring_arm.position = Vector3.ZERO
        spring_arm.add_excluded_object(get_rid())
        spring_arm.spring_length = 5.35

    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    touch_ui_enabled = OS.has_feature("mobile") or force_touch_ui_on_desktop
    _update_camera_transform()
    _build_minimal_hud()
    _connect_game_notices()
    _refresh_vitals()

func _sync_character_collider_to_ground() -> void:
    if collision_shape == null or collision_shape.shape == null:
        return
    if collision_shape.shape is CapsuleShape3D:
        var capsule := collision_shape.shape as CapsuleShape3D
        # Godot's capsule height is total height. Placing its center at height/2
        # makes the collider bottom exactly local Y=0.
        collision_shape.position.y = capsule.height * 0.5

func _physics_process(delta: float) -> void:
    # Dentro do carro: personagem/collider ficam fora da simulação e a posição
    # lógica acompanha o veículo para GPS, streaming e serviços da cidade.
    if in_vehicle_mode and is_instance_valid(vehicle):
        velocity = Vector3.ZERO
        global_position = (vehicle as Node3D).global_position
        _update_vehicle_scan(delta)
        return
    elif in_vehicle_mode:
        vehicle = null
        _restore_player_after_vehicle()

    if visual == null:
        return

    if _chat_is_typing():
        cancel_combat_input()
    _update_aim_camera(delta)

    var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    if joystick != null and joystick.get_value().length() > axis.length():
        axis = joystick.get_value()
    if _chat_is_typing():
        axis = Vector2.ZERO

    input_dir = axis
    input_strength = clampf(axis.length(), 0.0, 1.0)
    var direction := Basis(Vector3.UP, cam_yaw) * Vector3(axis.x, 0.0, axis.y)
    if direction.length_squared() > 0.0001:
        direction = direction.normalized()
    var running_requested := (Input.is_action_pressed("sprint") or touch_sprint) and not aiming and not crouching
    is_sprinting = running_requested and input_strength > 0.03
    is_walking = not is_sprinting and input_strength > 0.03
    var speed: float = 1.0 if crouching else (RUN_SPEED if is_sprinting else WALK_SPEED)
    if roll_remaining > 0.0:
        roll_remaining = maxf(0.0, roll_remaining-delta)
        velocity.x = roll_direction.x * 20.0 * (roll_remaining/0.6)
        velocity.z = roll_direction.z * 20.0 * (roll_remaining/0.6)
    else:
        var acceleration := clampf(delta * ACCELERATION, 0.0, 1.0)
        velocity.x = lerpf(velocity.x, direction.x*speed*input_strength, acceleration)
        velocity.z = lerpf(velocity.z, direction.z*speed*input_strength, acceleration)
    var was_grounded := is_on_floor()
    coyote_time = 0.10 if was_grounded else maxf(0.0, coyote_time-delta)
    jump_buffer = maxf(0.0,jump_buffer-delta)
    landing_weight = maxf(0.0,landing_weight-delta*5.5)
    if Input.is_action_just_pressed("jump"):
        _request_jump()
    if jump_buffer > 0.0 and coyote_time > 0.0 and roll_remaining <= 0.0 and not _chat_is_typing():
        crouching = false
        velocity.y = JUMP_SPEED
        jump_buffer = 0.0
        coyote_time = 0.0
    elif was_grounded:
        velocity.y = -0.1
    else:
        velocity.y -= 28.0 * delta
    is_jumping = not was_grounded and velocity.y > 0.0
    var falling_speed := velocity.y
    move_and_slide()
    if not was_grounded and is_on_floor() and falling_speed < -20.0:
        _request_roll()
    var flat_speed := Vector2(velocity.x,velocity.z).length()
    if (aiming or _combat_pose_active()) and roll_remaining <= 0.0:
        visual.rotation.y = cam_yaw + PI
    elif flat_speed > 0.08:
        visual.rotation.y = lerp_angle(visual.rotation.y,atan2(velocity.x,velocity.z),clampf(delta*7.0,0.0,1.0))
    visual.set_motion(flat_speed, selected_weapon >= 0, running_requested, delta)
    var reload_progress: float = -1.0
    if reload_remaining > 0.0 and reloading_weapon == selected_weapon and selected_weapon >= 0:
        reload_progress = 1.0 - reload_remaining / maxf(RELOAD_TIME[selected_weapon], 0.001)
    var switch_progress: float = -1.0
    if weapon_switch_remaining > 0.0 and weapon_switch_duration > 0.0:
        switch_progress = 1.0 - weapon_switch_remaining / weapon_switch_duration
    visual.update_pose(delta, aiming, _camera_shot_direction(), selected_weapon, not is_on_floor(), velocity.y, landing_weight, reload_progress, switch_progress, _combat_pose_active())
    _update_weapon_runtime(delta)

    _update_vehicle_scan(delta)
    if not _chat_is_typing() and nearby_vehicle != null:
        if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("enter_vehicle"):
            _try_enter_vehicle()


func _input(event: InputEvent) -> void:
    # O toque tem controle proprio; ignora seu mouse sintetico para nao
    # duplicar disparo, giro de camera ou captura entre dedos diferentes.
    if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
        return
    # Chat first: T reopens it. Any click/touch outside hides it completely.
    if text_chat != null and event is InputEventKey:
        if bool(text_chat.call("handle_key",event)):
            get_viewport().set_input_as_handled()
            return

    if event is InputEventMouseButton:
        var click := event as InputEventMouseButton
        if click.pressed and text_chat != null and text_chat.has_method("dismiss_if_outside"):
            text_chat.call("dismiss_if_outside",click.position)
        if click.button_index == MOUSE_BUTTON_LEFT:
            # Fora da mira, o esquerdo so arrasta a camera; mirando, tambem atira.
            camera_dragging = click.pressed and not mouse_over_interactive_ui() and not _chat_is_typing() and vehicle == null and not get_tree().paused
            if camera_dragging:
                collapse_text_chat()
            _set_fire_held(camera_dragging and aim_trigger_held)
            _sync_mouse_capture()
        elif click.button_index == MOUSE_BUTTON_RIGHT:
            if click.pressed and selected_weapon >= 0 and not mouse_over_interactive_ui() and not _chat_is_typing():
                _toggle_aiming()
        elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP and spring_arm != null and not mouse_over_interactive_ui():
            free_camera_distance = maxf(2.2,free_camera_distance-0.35)
        elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN and spring_arm != null and not mouse_over_interactive_ui():
            free_camera_distance = minf(10.0,free_camera_distance+0.35)
    elif event is InputEventMouseMotion and (camera_dragging or aim_trigger_held) and vehicle == null and not _chat_is_typing() and not get_tree().paused:
        var motion := event as InputEventMouseMotion
        cam_yaw -= motion.relative.x * mouse_sensitivity * (0.72 if aim_trigger_held else 1.0)
        cam_pitch = clampf(cam_pitch-motion.relative.y*mouse_sensitivity*(0.72 if aim_trigger_held else 1.0),deg_to_rad(-55.0),deg_to_rad(35.0))
        _update_camera_transform()
    elif event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed and text_chat != null and text_chat.has_method("dismiss_if_outside"):
            text_chat.call("dismiss_if_outside",touch.position)
        var viewport_size := get_viewport().get_visible_rect().size
        if touch.pressed and touch_look_index == -1 and not _point_over_interactive_ui(touch.position) and touch.position.x > viewport_size.x*0.45 and touch.position.y < viewport_size.y-160.0:
            touch_look_index = touch.index
        elif not touch.pressed and touch.index == touch_look_index:
            touch_look_index = -1
    elif event is InputEventScreenDrag and event.index == touch_look_index:
        cam_yaw -= event.relative.x*touch_sensitivity
        cam_pitch = clampf(cam_pitch-event.relative.y*touch_sensitivity,deg_to_rad(-55.0),deg_to_rad(35.0))
        _update_camera_transform()

    if _chat_is_typing():
        return
    if event is InputEventKey and event.pressed and not event.echo and text_chat != null and text_chat.visible:
        if text_chat.has_method("set_collapsed"):
            text_chat.call("set_collapsed",true)
    if event is InputEventKey:
        var key := event as InputEventKey
        if not key.pressed or key.echo:
            return
        if key.keycode == KEY_ESCAPE:
            cancel_combat_input()
        elif key.keycode == KEY_X:
            _toggle_crouch()
        elif key.keycode == KEY_CTRL:
            _request_roll()
        elif key.keycode == KEY_F:
            _select_weapon(-1 if selected_weapon >= 0 else 0)
        elif key.keycode == KEY_R:
            _request_reload()
        elif key.keycode == KEY_1:
            _select_weapon(0)
        elif key.keycode == KEY_2:
            _select_weapon(1)
        elif key.keycode == KEY_3:
            _select_weapon(2)
        elif key.keycode == KEY_4:
            _select_weapon(3)
        elif key.keycode == KEY_5:
            _select_weapon(WEAPONS.POLICE_SLOT)
        elif key.keycode == KEY_0:
            _select_weapon(-1)

func is_police_role() -> bool:
    return game_state != null and bool(game_state.get("is_police"))

func set_police_role(enabled: bool) -> void:
    if game_state == null:
        return
    game_state.set("is_police", enabled)
    if enabled:
        game_state.set("is_medic", false)
        game_state.set("is_military", false)

    if visual != null and visual.has_method("set_police_mode"):
        visual.call("set_police_mode", enabled)
    if enabled and visual != null and visual.has_method("set_medical_mode"):
        visual.call("set_medical_mode", false)

    cancel_combat_input()
    if enabled:
        armor = 100.0
        _refresh_vitals()
        _select_weapon(WEAPONS.POLICE_SLOT)
        if game_state.has_signal("game_notice"):
            game_state.emit_signal("game_notice", "POLICIA", "Você entrou em serviço. M16 e viaturas liberadas.")
    else:
        _select_weapon(-1)
        if game_state.has_signal("game_notice"):
            game_state.emit_signal("game_notice", "POLICIA", "Você saiu de serviço.")

func is_medic_role() -> bool:
    return game_state != null and bool(game_state.get("is_medic"))

func set_medic_role(enabled: bool) -> void:
    if game_state == null:
        return
    game_state.set("is_medic", enabled)
    if enabled:
        game_state.set("is_police", false)
        game_state.set("is_military", false)

    if visual != null and visual.has_method("set_medical_mode"):
        visual.call("set_medical_mode", enabled)
    if enabled and visual != null and visual.has_method("set_police_mode"):
        visual.call("set_police_mode", false)

    # Médico usa o mesmo corpo/rig e fica de mãos livres nesta etapa.
    cancel_combat_input()
    _select_weapon(-1)
    if game_state.has_signal("game_notice"):
        if enabled:
            game_state.emit_signal("game_notice", "HOSPITAL", "Você entrou em serviço como médico.")
        else:
            game_state.emit_signal("game_notice", "HOSPITAL", "Você saiu do serviço médico.")

func is_military_role() -> bool:
    return game_state != null and bool(game_state.get("is_military"))

func set_military_role(enabled: bool) -> void:
    if game_state == null:
        return
    game_state.set("is_military", enabled)
    if enabled:
        game_state.set("is_police", false)
        game_state.set("is_medic", false)
    if visual != null and visual.has_method("set_military_mode"):
        visual.call("set_military_mode", enabled)
    if enabled and visual != null:
        if visual.has_method("set_police_mode"):
            visual.call("set_police_mode", false)
        if visual.has_method("set_medical_mode"):
            visual.call("set_medical_mode", false)
    cancel_combat_input()
    _select_weapon(WEAPONS.ARMY_SLOT if enabled else -1)
    if game_state.has_signal("game_notice"):
        if enabled:
            game_state.emit_signal("game_notice", "EXERCITO", "Você entrou em serviço militar. AK-47, Hammer e caminhão liberados.")
        else:
            game_state.emit_signal("game_notice", "EXERCITO", "Você saiu do serviço militar.")

func _toggle_crouch() -> void:
    if vehicle == null and not _chat_is_typing() and roll_remaining <= 0.0:
        crouching = not crouching

func _request_roll() -> void:
    if vehicle != null or _chat_is_typing() or roll_remaining > 0.0 or not is_on_floor():
        return
    roll_remaining = 0.6
    roll_direction = Vector3(velocity.x,0,velocity.z).normalized()
    if roll_direction.length_squared() < 0.01:
        roll_direction = visual.global_basis.z.normalized()
    reload_remaining = 0.0
    reloading_weapon = -1
    cancel_combat_input()
    visual.start_roll()

func _select_weapon(index: int) -> void:
    selected_weapon = index if index >= -1 and index < WEAPON_NAMES.size() else -1
    cancel_combat_input()
    reload_remaining = 0.0
    reloading_weapon = -1
    if is_instance_valid(reload_audio):
        reload_audio.stop()
    if is_instance_valid(muzzle_flash):
        muzzle_flash.visible = false
    muzzle_time = 0.0
    weapon_switch_remaining = 0.0
    weapon_switch_duration = 0.0
    if selected_weapon >= 0 and selected_weapon < WEAPON_SWITCH_TIME.size():
        weapon_switch_duration = WEAPON_SWITCH_TIME[selected_weapon]
        weapon_switch_remaining = weapon_switch_duration
    for i in range(weapon_nodes.size()):
        weapon_nodes[i].visible = i == selected_weapon
    _refresh_weapon_hud()
    _refresh_aim_reticle()

func _update_camera_transform() -> void:
    if camera_pivot != null:
        camera_pivot.rotation = Vector3(cam_pitch + camera_recoil, cam_yaw, 0.0)

func _sync_mouse_capture() -> void:
    var capture := (camera_dragging or aim_trigger_held) and vehicle == null and not _chat_is_typing() and not get_tree().paused and not OS.has_feature("mobile")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE

func _connect_game_notices() -> void:
    if game_state == null:
        return
    if game_state.has_signal("game_notice"):
        var callback := Callable(self,"_on_game_notice")
        if not game_state.is_connected("game_notice",callback):
            game_state.connect("game_notice",callback)
    if game_state.has_signal("stats_changed"):
        var stats_callback := Callable(self,"_refresh_money")
        if not game_state.is_connected("stats_changed",stats_callback):
            game_state.connect("stats_changed",stats_callback)
    _refresh_money()

func _on_game_notice(category: String, message: String) -> void:
    if text_chat == null or not is_instance_valid(text_chat):
        return
    text_chat.call("add_message",category,message)

func _refresh_money() -> void:
    if game_state == null:
        return
    if money_label != null and is_instance_valid(money_label):
        money_label.text = "R$ %d" % int(game_state.get("money"))
    if main_coins_label != null and is_instance_valid(main_coins_label):
        main_coins_label.text = "MC %d" % int(game_state.get("main_coins"))

func _open_shop() -> void:
    if map_settings_menu != null and is_instance_valid(map_settings_menu):
        if map_settings_menu.has_method("open_shop"):
            map_settings_menu.call("open_shop")
            return
    if text_chat != null and is_instance_valid(text_chat):
        text_chat.call("add_message","LOJA","Main Coins: MC %d" % int(game_state.get("main_coins")))

func _refresh_vitals() -> void:
    health = clampf(health, 0.0, 100.0)
    armor = clampf(armor, 0.0, 100.0)
    if health_bar != null:
        health_bar.value = health
    if armor_bar != null:
        armor_bar.value = armor
    if health_text != null:
        health_text.text = "VIDA  %d%%" % roundi(health)
    if armor_text != null:
        armor_text.text = "COLETE  %d%%" % roundi(armor)

func _chat_is_typing() -> bool:
    return bool(get_tree().get_meta("br1_chat_typing", false))

func mouse_over_interactive_ui() -> bool:
    var hovered: Control = get_viewport().gui_get_hovered_control()
    if hovered == null:
        return false
    return hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE

func _point_over_interactive_ui(point: Vector2) -> bool:
    if text_chat != null and text_chat.visible and text_chat.get_global_rect().has_point(point):
        return true
    if minimap != null and minimap.get_global_rect().has_point(point):
        return true
    if map_settings_menu != null and bool(map_settings_menu.get("menu_open")):
        return true
    if joystick != null and joystick.is_visible_in_tree() and joystick.get_global_rect().has_point(point):
        return true
    for ui_root in [hud_root, map_settings_menu]:
        if ui_root == null:
            continue
        for node in ui_root.find_children("*", "Button", true, false):
            var control := node as Button
            if control != null and control.is_visible_in_tree() and control.get_global_rect().has_point(point):
                return true
    return false

func collapse_text_chat() -> void:
    if text_chat == null:
        return
    if text_chat.has_method("hide_chat"):
        text_chat.call("hide_chat")
    elif text_chat.has_method("set_collapsed"):
        text_chat.call("set_collapsed",true)

func enter_vehicle_mode(target_vehicle: Node) -> void:
    if target_vehicle == null or vehicle != null:
        return
    cancel_combat_input()
    roll_remaining = 0.0
    crouching = false
    vehicle = target_vehicle
    in_vehicle_mode = true
    vehicle_exit_callback = _on_vehicle_tree_exiting.bind(target_vehicle)
    target_vehicle.tree_exiting.connect(vehicle_exit_callback, CONNECT_ONE_SHOT)
    nearby_vehicle = null
    velocity = Vector3.ZERO
    touch_sprint = false
    if visual != null:
        if visual.has_method("set_motion"):
            visual.call("set_motion", 0.0, false)
        visual.visible = false
    if collision_shape != null:
        collision_shape.set_deferred("disabled", true)
    if touch_root != null:
        touch_root.visible = false
    if enter_vehicle_button != null:
        enter_vehicle_button.visible = false

func exit_vehicle_mode(_door_point: Vector3, safe_point: Vector3) -> void:
    # Keep the player's capsule disabled while moving it away from the vehicle.
    # Previously the raw safe_point inherited the vehicle height; when the
    # capsule came back overlapping the car/ground, Godot could resolve the
    # penetration by launching the player upward.
    var old_vehicle: Node = vehicle
    if is_instance_valid(old_vehicle) and old_vehicle.tree_exiting.is_connected(vehicle_exit_callback):
        old_vehicle.tree_exiting.disconnect(vehicle_exit_callback)
    vehicle = null
    in_vehicle_mode = false
    var grounded_exit: Vector3 = _project_vehicle_exit_to_ground(safe_point, old_vehicle)
    global_position = grounded_exit
    velocity = Vector3.ZERO
    if camera != null:
        camera.current = true
    _update_camera_transform()

    # Give physics one frame with the capsule disabled at the new position,
    # then restore it and floor-snap on the following frame.
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    _restore_player_after_vehicle()
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    velocity = Vector3.ZERO
    apply_floor_snap()

func _project_vehicle_exit_to_ground(point: Vector3, old_vehicle: Node) -> Vector3:
    if not is_inside_tree() or get_world_3d() == null:
        return point
    var ray_from: Vector3 = point + Vector3.UP * 3.5
    var ray_to: Vector3 = point + Vector3.DOWN * 7.5
    var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
    query.collide_with_areas = false
    var excluded: Array[RID] = []
    excluded.append(get_rid())
    if old_vehicle is CollisionObject3D:
        excluded.append((old_vehicle as CollisionObject3D).get_rid())
    query.exclude = excluded
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        var ground_point: Vector3 = hit.get("position", point)
        # Player root fica na altura dos pes.
        ground_point.y += 0.035
        return ground_point
    return point

func _on_vehicle_tree_exiting(target_vehicle: Node) -> void:
    if not is_inside_tree() or vehicle != target_vehicle:
        return
    # Limpa as excecoes antes de o RID do carro ser destruido.
    if target_vehicle is PhysicsBody3D:
        remove_collision_exception_with(target_vehicle)
        (target_vehicle as PhysicsBody3D).remove_collision_exception_with(self)
    if target_vehicle.is_queued_for_deletion():
        vehicle = null
        velocity = Vector3.ZERO
        _restore_player_after_vehicle()

func _restore_player_after_vehicle() -> void:
    in_vehicle_mode = false
    if camera != null:
        camera.current = true
        _update_camera_transform()
    if visual != null:
        visual.visible = true
        if visual.has_method("set_motion"):
            visual.call("set_motion", 0.0, selected_weapon >= 0)
    if collision_shape != null:
        collision_shape.set_deferred("disabled", false)
    set_mobile_controls_enabled(touch_ui_enabled or OS.has_feature("mobile"))
    vehicle_scan_clock = 1.0

func _build_minimal_hud() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.name = "GameUI"
    hud_layer.layer = 20
    add_child(hud_layer)

    hud_root = Control.new()
    hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(hud_root)

    # Mapa redondo igual ao sistema anterior.
    minimap = MiniMapScript.new()
    minimap.name = "MiniMapa"
    minimap.position = Vector2(24.0,24.0)
    minimap.size = Vector2(196.0,196.0)
    minimap.custom_minimum_size = Vector2(196.0,196.0)
    hud_root.add_child(minimap)
    minimap.call("set_target",self)
    minimap.set("redraw_interval",0.08 if OS.has_feature("mobile") else 0.05)

    # Chat preservado.
    text_chat = TextChatScript.new()
    hud_root.add_child(text_chat)
    text_chat.call("setup",self)

    # Carteira no topo direito: LOJA > DINHEIRO > MAIN COINS.
    # Fundo quase transparente e linha fina para manter a HUD sofisticada.
    store_button = MobileActionButtonScript.new()
    store_button.name = "BotaoLoja"
    store_button.call("configure", "LOJA", "Loja")
    store_button.anchor_left = 1.0
    store_button.anchor_right = 1.0
    store_button.offset_left = -438.0
    store_button.offset_right = -394.0
    store_button.offset_top = 14.0
    store_button.offset_bottom = 50.0
    store_button.pressed.connect(_open_shop)
    hud_root.add_child(store_button)

    money_panel = PanelContainer.new()
    money_panel.name = "DinheiroPainel"
    money_panel.anchor_left = 1.0
    money_panel.anchor_right = 1.0
    money_panel.offset_left = -386.0
    money_panel.offset_right = -170.0
    money_panel.offset_top = 14.0
    money_panel.offset_bottom = 50.0
    var money_style := StyleBoxFlat.new()
    money_style.bg_color = Color(0.015,0.045,0.065,0.20)
    money_style.border_color = Color(0.32,0.74,0.82,0.34)
    money_style.set_border_width_all(1)
    money_style.set_corner_radius_all(7)
    money_style.content_margin_left = 10
    money_style.content_margin_right = 10
    money_style.content_margin_top = 3
    money_style.content_margin_bottom = 3
    money_panel.add_theme_stylebox_override("panel",money_style)
    hud_root.add_child(money_panel)

    money_label = Label.new()
    money_label.name = "DinheiroDireita"
    money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    money_label.add_theme_font_size_override("font_size",19)
    money_label.add_theme_color_override("font_color",Color(0.32,0.95,0.76,1.0))
    money_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.82))
    money_label.add_theme_constant_override("shadow_offset_x",1)
    money_label.add_theme_constant_override("shadow_offset_y",1)
    money_panel.add_child(money_label)

    coins_panel = PanelContainer.new()
    coins_panel.name = "MainCoinsPainel"
    coins_panel.anchor_left = 1.0
    coins_panel.anchor_right = 1.0
    coins_panel.offset_left = -162.0
    coins_panel.offset_right = -18.0
    coins_panel.offset_top = 14.0
    coins_panel.offset_bottom = 50.0
    var coins_style := StyleBoxFlat.new()
    coins_style.bg_color = Color(0.015,0.045,0.065,0.20)
    coins_style.border_color = Color(0.86,0.72,0.38,0.38)
    coins_style.set_border_width_all(1)
    coins_style.set_corner_radius_all(7)
    coins_style.content_margin_left = 10
    coins_style.content_margin_right = 10
    coins_style.content_margin_top = 3
    coins_style.content_margin_bottom = 3
    coins_panel.add_theme_stylebox_override("panel",coins_style)
    hud_root.add_child(coins_panel)

    main_coins_label = Label.new()
    main_coins_label.name = "MainCoinsDireita"
    main_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    main_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    main_coins_label.add_theme_font_size_override("font_size",18)
    main_coins_label.add_theme_color_override("font_color",Color(1.0,0.84,0.46,1.0))
    main_coins_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.82))
    main_coins_label.add_theme_constant_override("shadow_offset_x",1)
    main_coins_label.add_theme_constant_override("shadow_offset_y",1)
    coins_panel.add_child(main_coins_label)
    _refresh_money()

    # VIDA / COLETE: largura, tipografia e barras finas do HUD anterior.
    var holder := PanelContainer.new()
    holder.name = "VidaEColeteDireita"
    holder.anchor_left = 1.0
    holder.anchor_right = 1.0
    holder.offset_left = -318.0
    holder.offset_right = -18.0
    holder.offset_top = 54.0
    holder.offset_bottom = 104.0
    holder.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    hud_root.add_child(holder)

    var vitals := VBoxContainer.new()
    vitals.add_theme_constant_override("separation",2)
    holder.add_child(vitals)

    var life_row := HBoxContainer.new()
    life_row.custom_minimum_size = Vector2(300,21)
    life_row.add_theme_constant_override("separation",6)
    vitals.add_child(life_row)
    health_text = _make_vital_label("VIDA  100%",Color(1.0,.86,.86,1.0))
    life_row.add_child(health_text)
    health_bar = _make_vital_bar(Color(.98,.12,.15,1.0))
    life_row.add_child(health_bar)

    var armor_row := HBoxContainer.new()
    armor_row.custom_minimum_size = Vector2(300,21)
    armor_row.add_theme_constant_override("separation",6)
    vitals.add_child(armor_row)
    armor_text = _make_vital_label("COLETE  100%",Color(.82,.92,1.0,1.0))
    armor_row.add_child(armor_text)
    armor_bar = _make_vital_bar(Color(.10,.52,1.0,1.0))
    armor_row.add_child(armor_bar)

    touch_root = Control.new()
    touch_root.name = "BotoesDoPersonagem"
    touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    touch_root.process_mode = Node.PROCESS_MODE_ALWAYS
    touch_root.z_index = 50
    hud_root.add_child(touch_root)

    # Analógico exatamente no tamanho/posição do HUD antigo.
    joystick = Control.new()
    joystick.set_script(VirtualJoystickScript)
    joystick.anchor_top = 1.0
    joystick.anchor_bottom = 1.0
    joystick.offset_left = 24.0
    joystick.offset_right = 279.0
    joystick.offset_top = -279.0
    joystick.offset_bottom = -24.0
    touch_root.add_child(joystick)

    # Preserve action IDs and saved positions; the artwork is independent of fonts.
    enter_vehicle_button = _make_touch_button("ENTRAR",Vector2(-504,-486),Vector2(-364,-366),18)
    enter_vehicle_button.visible = false
    enter_vehicle_button.pressed.connect(_try_enter_vehicle)
    touch_root.add_child(enter_vehicle_button)
    touch_buttons["ENTRAR"] = enter_vehicle_button

    fire_button_ref = _make_touch_button("ATIRAR",Vector2(-186,-486),Vector2(-34,-366),22)
    fire_button_ref.button_down.connect(_set_fire_held.bind(true))
    fire_button_ref.button_up.connect(_set_fire_held.bind(false))
    touch_root.add_child(fire_button_ref)
    touch_buttons["ATIRAR"] = fire_button_ref

    aim_button_ref = _make_touch_button("MIRAR",Vector2(-342,-486),Vector2(-202,-366),20)
    aim_button_ref.tooltip_text = "Toque para ligar/desligar a mira"
    aim_button_ref.pressed.connect(_toggle_aiming)
    touch_root.add_child(aim_button_ref)
    touch_buttons["MIRAR"] = aim_button_ref

    reload_button_ref = _make_touch_button("RECARGA",Vector2(-342,-324),Vector2(-202,-204),17)
    reload_button_ref.pressed.connect(_request_reload)
    touch_root.add_child(reload_button_ref)
    touch_buttons["RECARGA"] = reload_button_ref

    var jump_button := _make_touch_button("PULAR",Vector2(-180,-324),Vector2(-40,-204),20)
    jump_button.button_down.connect(_request_jump)
    touch_root.add_child(jump_button)
    touch_buttons["PULAR"] = jump_button

    var run_button := _make_touch_button("CORRER",Vector2(-342,-162),Vector2(-202,-42),18)
    run_button.button_down.connect(func(): touch_sprint = true)
    run_button.button_up.connect(func(): touch_sprint = false)
    touch_root.add_child(run_button)
    touch_buttons["CORRER"] = run_button

    var use_button := _make_touch_button("USAR",Vector2(-180,-162),Vector2(-40,-42),22)
    use_button.pressed.connect(_try_enter_vehicle)
    touch_root.add_child(use_button)
    touch_buttons["USAR"] = use_button

    var crouch_button := _make_touch_button("ABAIXAR",Vector2(-504,-324),Vector2(-364,-204),16)
    crouch_button.pressed.connect(_toggle_crouch)
    touch_root.add_child(crouch_button)
    touch_buttons["ABAIXAR"] = crouch_button
    var roll_button := _make_touch_button("ROLAR",Vector2(-504,-162),Vector2(-364,-42),18)
    roll_button.pressed.connect(_request_roll)
    touch_root.add_child(roll_button)
    touch_buttons["ROLAR"] = roll_button

    # HUD moderna: mostra somente o item que esta na mao.
    weapon_hud = PanelContainer.new()
    weapon_hud.name = "ArmaAtual"
    weapon_hud.anchor_left = 1.0
    weapon_hud.anchor_right = 1.0
    weapon_hud.offset_left = -318.0
    weapon_hud.offset_right = -18.0
    weapon_hud.offset_top = 108.0
    weapon_hud.offset_bottom = 158.0
    var weapon_style := StyleBoxFlat.new()
    weapon_style.bg_color = Color(0.025,0.055,0.09,0.72)
    weapon_style.border_color = Color(0.28,0.72,0.92,0.38)
    weapon_style.set_border_width_all(1)
    weapon_style.set_corner_radius_all(12)
    weapon_style.content_margin_left = 12
    weapon_style.content_margin_right = 12
    weapon_style.content_margin_top = 6
    weapon_style.content_margin_bottom = 6
    weapon_hud.add_theme_stylebox_override("panel",weapon_style)
    hud_root.add_child(weapon_hud)
    var weapon_row := HBoxContainer.new()
    weapon_row.alignment = BoxContainer.ALIGNMENT_CENTER
    weapon_row.add_theme_constant_override("separation",8)
    weapon_hud.add_child(weapon_row)
    weapon_prev_button = MobileActionButtonScript.new()
    weapon_prev_button.name = "TrocarArmaAnterior"
    weapon_prev_button.call("configure", "ANTERIOR", "Arma anterior")
    weapon_prev_button.custom_minimum_size = Vector2(34,34)
    weapon_prev_button.visible = touch_ui_enabled
    weapon_prev_button.pressed.connect(_cycle_weapon.bind(-1))
    weapon_row.add_child(weapon_prev_button)
    weapon_hud_icon = TextureRect.new()
    weapon_hud_icon.custom_minimum_size = Vector2(36,34)
    weapon_hud_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    weapon_hud_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    weapon_hud_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weapon_row.add_child(weapon_hud_icon)
    weapon_hud_name = Label.new()
    weapon_hud_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    weapon_hud_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    weapon_hud_name.add_theme_font_size_override("font_size",14)
    weapon_hud_name.add_theme_color_override("font_color",Color(0.88,0.97,1.0))
    weapon_row.add_child(weapon_hud_name)
    weapon_next_button = MobileActionButtonScript.new()
    weapon_next_button.name = "TrocarArmaProxima"
    weapon_next_button.call("configure", "PROXIMA", "Próxima arma")
    weapon_next_button.custom_minimum_size = Vector2(34,34)
    weapon_next_button.visible = touch_ui_enabled
    weapon_next_button.pressed.connect(_cycle_weapon.bind(1))
    weapon_row.add_child(weapon_next_button)
    _refresh_weapon_hud()

    aim_reticle = preload("res://scripts/aim_reticle.gd").new()
    aim_reticle.name = "MiraCentral"
    hud_root.add_child(aim_reticle)
    aim_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    aim_reticle.offset_left = -24
    aim_reticle.offset_right = 24
    aim_reticle.offset_top = -24
    aim_reticle.offset_bottom = 24
    aim_reticle.visible = false

    # Menu de mapa/configuração reativado.
    map_settings_menu = MapSettingsMenuScript.new()
    add_child(map_settings_menu)
    map_settings_menu.call("setup",self)
    modern_ui = map_settings_menu
    minimap.pause_requested.connect(func(): map_settings_menu.call("open_page",1))

    set_mobile_controls_enabled(touch_ui_enabled)

func _refresh_weapon_hud() -> void:
    if weapon_hud_icon == null or weapon_hud_name == null:
        return
    if selected_weapon < 0:
        weapon_hud_icon.texture = MobileActionButtonScript.ICONS["USAR"]
        weapon_hud_name.text = "MÃOS LIVRES"
    else:
        weapon_hud_icon.texture = MobileActionButtonScript.ICONS["PISTOLA" if selected_weapon == 1 else "FUZIL"]
        weapon_hud_name.text = "%s   %d | %d" % [WEAPON_NAMES[selected_weapon], magazine_ammo[selected_weapon], reserve_ammo[selected_weapon]]

func _cycle_weapon(direction: int) -> void:
    if vehicle != null or _chat_is_typing() or get_tree().paused:
        return
    var order: Array[int] = [-1]
    for index in range(WEAPON_NAMES.size()):
        order.append(index)
    var current_index: int = order.find(selected_weapon)
    if current_index < 0:
        current_index = 0
    current_index = wrapi(current_index + direction, 0, order.size())
    _select_weapon(order[current_index])

func _toggle_aiming() -> void:
    _set_aiming(not aim_trigger_held)

func _set_fire_held(enabled: bool) -> void:
    if selected_weapon < 0 or vehicle != null or _chat_is_typing() or get_tree().paused or roll_remaining > 0.0:
        fire_held = false
        fire_press_pending = false
        semi_auto_pending = false
        aiming = aim_trigger_held
        _refresh_aim_reticle()
        return
    var was_held: bool = fire_held
    if enabled and not was_held:
        fire_cooldown = maxf(0.0, fire_cooldown)
        fire_press_pending = WEAPON_AUTOMATIC[selected_weapon]
    fire_held = enabled
    if enabled:
        fire_pose_remaining = 0.45
    # Pistola do pacote original e semiautomatica: um tiro por toque/clique.
    if selected_weapon < WEAPON_AUTOMATIC.size() and not WEAPON_AUTOMATIC[selected_weapon]:
        # Mantem o pedido ate o proximo frame valido; soltar rapidamente o
        # mouse/touch nao pode cancelar o disparo semiautomatico.
        if enabled and not was_held:
            semi_auto_pending = true

func _set_aiming(enabled: bool) -> void:
    aim_trigger_held = enabled and selected_weapon >= 0 and vehicle == null and roll_remaining <= 0.0 and not _chat_is_typing() and not get_tree().paused
    if not aim_trigger_held:
        fire_held = false
        fire_press_pending = false
        semi_auto_pending = false
        fire_pose_remaining = 0.0
    aiming = aim_trigger_held
    if aiming:
        collapse_text_chat()
    _sync_mouse_capture()
    _refresh_aim_reticle()

func _refresh_aim_reticle() -> void:
    if aim_reticle != null:
        aim_reticle.visible = aiming and selected_weapon >= 0 and vehicle == null
    if aim_button_ref != null:
        aim_button_ref.call("set_active", aim_trigger_held)
    var crouch_button := touch_buttons.get("ABAIXAR") as Button
    if crouch_button != null:
        crouch_button.call("set_active", crouching)

func _combat_pose_active() -> bool:
    return selected_weapon >= 0 and vehicle == null and roll_remaining <= 0.0 and not _chat_is_typing() and not get_tree().paused and (aim_trigger_held or fire_held or fire_press_pending or semi_auto_pending or fire_pose_remaining > 0.0)

func _update_weapon_runtime(delta: float) -> void:
    fire_pose_remaining = 0.45 if fire_held else maxf(0.0,fire_pose_remaining-delta)
    aiming = selected_weapon >= 0 and roll_remaining <= 0.0 and aim_trigger_held
    _refresh_aim_reticle()
    fire_cooldown = maxf(-delta, fire_cooldown - delta)
    if absf(fire_cooldown) < 0.000001:
        fire_cooldown = 0.0
    weapon_switch_remaining = maxf(0.0, weapon_switch_remaining - delta)
    if Engine.get_process_frames() != muzzle_flash_frame:
        muzzle_time = maxf(0.0, muzzle_time - delta)
    if muzzle_time <= 0.0 and is_instance_valid(muzzle_flash):
        muzzle_flash.visible = false

    if reload_remaining > 0.0:
        reload_remaining = maxf(0.0, reload_remaining - delta)
        if reload_remaining <= 0.0 and reloading_weapon >= 0 and reloading_weapon < magazine_ammo.size():
            var refill := mini(MAGAZINE_SIZE[reloading_weapon] - magazine_ammo[reloading_weapon], reserve_ammo[reloading_weapon])
            magazine_ammo[reloading_weapon] += refill
            reserve_ammo[reloading_weapon] -= refill
            reloading_weapon = -1
            _refresh_weapon_hud()

    if (fire_held or fire_press_pending) and selected_weapon >= 0 and reload_remaining <= 0.0:
        if selected_weapon < WEAPON_AUTOMATIC.size() and WEAPON_AUTOMATIC[selected_weapon]:
            var shots := 0
            while fire_cooldown <= 0.0 and shots < MAX_SHOTS_PER_TICK:
                if not _try_fire_weapon():
                    fire_cooldown = maxf(0.0, fire_cooldown)
                    break
                fire_press_pending = false
                shots += 1
                if not fire_held:
                    break
    if semi_auto_pending and selected_weapon >= 0 and selected_weapon < WEAPON_AUTOMATIC.size() and not WEAPON_AUTOMATIC[selected_weapon]:
        if reload_remaining <= 0.0 and weapon_switch_remaining <= 0.0 and fire_cooldown <= 0.0 and visual != null and visual.motion_ready and _weapon_anim_aim_weight() >= .92 and absf(angle_difference(visual.rotation.y, cam_yaw+PI)) <= .15:
            if _try_fire_weapon():
                semi_auto_pending = false

func _request_reload() -> void:
    if selected_weapon < 0 or vehicle != null or _chat_is_typing() or get_tree().paused or roll_remaining > 0.0 or reload_remaining > 0.0 or weapon_switch_remaining > 0.0 or reserve_ammo[selected_weapon] <= 0:
        return
    if magazine_ammo[selected_weapon] >= MAGAZINE_SIZE[selected_weapon]:
        return

    fire_held = false
    fire_press_pending = false
    semi_auto_pending = false
    reloading_weapon = selected_weapon
    reload_remaining = RELOAD_TIME[selected_weapon]
    if reload_audio != null:
        reload_audio.stop()
        if selected_weapon >= 0 and selected_weapon < WEAPONS.ANIMATION_KIND.size():
            reload_audio.stream = RELOAD_SOUNDS[WEAPONS.ANIMATION_KIND[selected_weapon]]
        reload_audio.play()

func _try_fire_weapon() -> bool:
    if selected_weapon < 0 or selected_weapon >= WEAPON_AUTOMATIC.size():
        return false
    var trigger_active: bool = (fire_held or fire_press_pending) if WEAPON_AUTOMATIC[selected_weapon] else semi_auto_pending
    if not trigger_active or not _combat_pose_active() or roll_remaining > 0.0 or get_tree().paused or not visual.motion_ready or _weapon_anim_aim_weight() < .92:
        return false
    if absf(angle_difference(visual.rotation.y, cam_yaw+PI)) > .15:
        return false
    if selected_weapon < 0 or vehicle != null or _chat_is_typing():
        return false
    if fire_cooldown > 0.0 or reload_remaining > 0.0 or weapon_switch_remaining > 0.0:
        return false

    if magazine_ammo[selected_weapon] <= 0:
        fire_cooldown = 0.22
        _play_empty_click()
        _request_reload()
        fire_press_pending = false
        semi_auto_pending = false
        return false

    magazine_ammo[selected_weapon] -= 1
    fire_cooldown += FIRE_RATES[selected_weapon]
    _refresh_weapon_hud()
    _play_weapon_sound()
    _show_muzzle_flash()
    _set_weapon_anim_recoil(deg_to_rad(0.5 if selected_weapon == 1 else 0.8))

    var shot := _calculate_shot_hit()
    var muzzle_position: Vector3 = _weapon_muzzle_position()
    var target_position: Vector3 = shot.get("position", muzzle_position + _camera_shot_direction() * WEAPON_RANGE)
    _spawn_tracer(muzzle_position, target_position)

    if bool(shot.get("hit", false)):
        _apply_shot_hit(shot)

    var shot_recoil_deg: float = 0.8 if WEAPONS.ANIMATION_KIND[selected_weapon] == 0 else 0.5
    camera_recoil = minf(camera_recoil + deg_to_rad(shot_recoil_deg), deg_to_rad(3.0))
    _update_camera_transform()
    return true

func _camera_shot_direction() -> Vector3:
    if camera == null:
        return -global_transform.basis.z
    return -camera.global_basis.z.normalized()

func _weapon_muzzle_position() -> Vector3:
    if selected_weapon >= 0 and selected_weapon < weapon_muzzles.size():
        return weapon_muzzles[selected_weapon].global_position
    return global_position + Vector3.UP * 1.45

func _calculate_shot_hit() -> Dictionary:
    if camera == null:
        return {
            "hit": false,
            "position": _weapon_muzzle_position() + _camera_shot_direction() * WEAPON_RANGE
        }

    var camera_origin: Vector3 = camera.global_position
    var camera_direction := _camera_shot_direction()
    var rifle := WEAPONS.ANIMATION_KIND[selected_weapon] == 0
    var spread := (18.0 if rifle else 25.0)
    spread += (5.5 if rifle else 3.5) * Vector2(velocity.x,velocity.z).length()
    spread += (-7.0 if aim_trigger_held else 0.0) + (-6.0 if crouching else 0.0) + (12.0 if not is_on_floor() else 0.0)
    var spread_rad := deg_to_rad(maxf(1.0,spread)/12.0)
    camera_direction = (camera_direction + camera.global_basis.x*randf_range(-spread_rad,spread_rad) + camera.global_basis.y*randf_range(-spread_rad,spread_rad)).normalized()
    var camera_end: Vector3 = camera_origin + camera_direction * WEAPON_RANGE

    var space := get_world_3d().direct_space_state
    camera_shot_query.from = camera_origin
    camera_shot_query.to = camera_end
    var camera_hit := space.intersect_ray(camera_shot_query)

    var aim_point: Vector3 = camera_hit.get("position", camera_end)
    var muzzle: Vector3 = _weapon_muzzle_position()

    # Segunda checagem parte do cano: impede atravessar parede/porta/veículo.
    muzzle_shot_query.from = muzzle
    muzzle_shot_query.to = aim_point
    var muzzle_hit := space.intersect_ray(muzzle_shot_query)

    var final_hit: Dictionary = muzzle_hit if not muzzle_hit.is_empty() else camera_hit
    if final_hit.is_empty():
        return {
            "hit": false,
            "position": aim_point,
            "direction": (aim_point - muzzle).normalized()
        }

    final_hit["hit"] = true
    final_hit["direction"] = (Vector3(final_hit["position"]) - muzzle).normalized()
    return final_hit

func _apply_shot_hit(hit: Dictionary) -> void:
    var collider: Object = hit.get("collider")
    var point: Vector3 = hit.get("position", Vector3.ZERO)
    var normal: Vector3 = hit.get("normal", Vector3.UP)
    var direction: Vector3 = hit.get("direction", _camera_shot_direction())

    if collider is RigidBody3D:
        var body := collider as RigidBody3D
        body.apply_impulse(direction * IMPACT_IMPULSE[selected_weapon], point - body.global_position)

    var node := collider as Node
    var depth: int = 0
    while node != null and depth < 8:
        if _invoke_damage_method(node, WEAPON_DAMAGE[selected_weapon], point, direction):
            break
        node = node.get_parent()
        depth += 1

    _spawn_impact(point, normal, collider)

func _invoke_damage_method(node: Node, damage_amount: float, point: Vector3, direction: Vector3) -> bool:
    var script: Script = node.get_script()
    var key: Variant = script.get_instance_id() if script != null else node.get_class()
    if not damage_method_cache.has(key):
        var signature: Dictionary = {}
        var methods := node.get_method_list()
        for method_name in DAMAGE_METHODS:
            if not node.has_method(method_name):
                continue
            for info in methods:
                if StringName(info.get("name", "")) == method_name:
                    var argc: int = (info.get("args", []) as Array).size()
                    if argc <= 3:
                        signature = {"method": method_name, "argc": argc}
                    break
            if not signature.is_empty():
                break
        damage_method_cache[key] = signature
    var signature: Dictionary = damage_method_cache[key]
    if signature.is_empty():
        return false
    var method_name: StringName = signature["method"]
    match int(signature["argc"]):
        0: node.call(method_name)
        1: node.call(method_name, damage_amount)
        2: node.call(method_name, damage_amount, point)
        3: node.call(method_name, damage_amount, point, direction)
    return true

func _spawn_impact(point: Vector3, normal: Vector3, collider: Object) -> void:
    shot_effects.impact(point, normal, collider is StaticBody3D)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
    shot_effects.tracer(from, to)

func _weapon_visual_node() -> Object:
    if visual == null:
        return null
    return visual

func _weapon_anim_aim_weight() -> float:
    var animator := _weapon_visual_node()
    if animator == null:
        return 0.0
    return float(animator.get("aim_weight"))

func _weapon_anim_recoil() -> float:
    var animator := _weapon_visual_node()
    if animator == null:
        return 0.0
    return float(animator.get("recoil"))

func _set_weapon_anim_recoil(value: float) -> void:
    var animator := _weapon_visual_node()
    if animator != null:
        animator.set("recoil", value)

func _show_muzzle_flash() -> void:
    if is_instance_valid(muzzle_flash):
        muzzle_flash.visible = false
    if selected_weapon < 0 or selected_weapon >= weapon_nodes.size():
        return
    muzzle_flash = weapon_flashes[selected_weapon]
    if muzzle_flash != null:
        muzzle_flash.visible = true
        muzzle_time = 0.075
        muzzle_flash_frame = Engine.get_process_frames()

func _play_weapon_sound() -> void:
    if gun_audio == null or selected_weapon < 0:
        return
    var sound: AudioStream = GUN_SOUNDS[WEAPONS.ANIMATION_KIND[selected_weapon]]
    if gun_audio.stream != sound:
        gun_audio.stream = sound
    gun_audio.play()

func _play_empty_click() -> void:
    if gun_audio == null:
        return
    if gun_audio.stream != EMPTY_SOUND:
        gun_audio.stream = EMPTY_SOUND
    gun_audio.play()

func _make_vital_label(value: String, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.custom_minimum_size = Vector2(84,20)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size",11)
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
    label.add_theme_constant_override("shadow_offset_x",1)
    label.add_theme_constant_override("shadow_offset_y",1)
    return label

func _make_vital_bar(color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(210,5)
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(.04,.055,.07,.72)
    bg.set_corner_radius_all(3)
    var fill := bg.duplicate() as StyleBoxFlat
    fill.bg_color = color
    bar.add_theme_stylebox_override("background",bg)
    bar.add_theme_stylebox_override("fill",fill)
    return bar

func _make_touch_button(text_value: String, top_left: Vector2, bottom_right: Vector2, font_size: int) -> Button:
    var button := MobileActionButtonScript.new()
    button.configure(text_value)
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    var size := 96.0 if text_value == "ATIRAR" else 84.0
    var center := (top_left+bottom_right)*.5
    button.offset_left = center.x-size*.5
    button.offset_top = center.y-size*.5
    button.offset_right = center.x+size*.5
    button.offset_bottom = center.y+size*.5
    button.pivot_offset = Vector2(size*.5,size*.5)
    var base_font := int(round(font_size*1.18))
    button.set_meta("base_font_size",base_font)
    button.set_meta("base_rect",Rect2(button.position,button.size))
    button.add_theme_font_size_override("font_size",base_font)
    return button

func reset_mobile_hud_layout() -> void:
    if touch_root == null:
        return

    # Joystick default, kept smaller than older mobile HUD.
    if joystick != null:
        joystick.anchor_left = 0.0
        joystick.anchor_right = 0.0
        joystick.anchor_top = 1.0
        joystick.anchor_bottom = 1.0
        joystick.offset_left = 24.0
        joystick.offset_right = 279.0
        joystick.offset_top = -279.0
        joystick.offset_bottom = -24.0

    var layouts := {
        "ENTRAR": Vector4(-504.0,-486.0,-364.0,-366.0),
        "ATIRAR": Vector4(-186.0,-486.0,-34.0,-366.0),
        "MIRAR": Vector4(-342.0,-486.0,-202.0,-366.0),
        "RECARGA": Vector4(-342.0,-324.0,-202.0,-204.0),
        "PULAR": Vector4(-180.0,-324.0,-40.0,-204.0),
        "CORRER": Vector4(-342.0,-162.0,-202.0,-42.0),
        "USAR": Vector4(-180.0,-162.0,-40.0,-42.0),
        "ABAIXAR": Vector4(-504.0,-324.0,-364.0,-204.0),
        "ROLAR": Vector4(-504.0,-162.0,-364.0,-42.0)
    }
    for action in layouts:
        var button := touch_buttons.get(action) as Button
        if button == null:
            continue
        var rect: Vector4 = layouts[action]
        button.anchor_left = 1.0
        button.anchor_right = 1.0
        button.anchor_top = 1.0
        button.anchor_bottom = 1.0
        var side := 96.0 if action == "ATIRAR" else 84.0
        var center := Vector2((rect.x+rect.z)*0.5,(rect.y+rect.w)*0.5)
        button.offset_left = center.x-side*0.5
        button.offset_top = center.y-side*0.5
        button.offset_right = center.x+side*0.5
        button.offset_bottom = center.y+side*0.5
        button.set_meta("base_rect",Rect2(button.position,button.size))

func _clamp_mobile_controls_to_screen() -> void:
    if touch_root == null:
        return
    var screen := get_viewport().get_visible_rect().size
    if screen.x <= 0.0 or screen.y <= 0.0:
        return
    for node in touch_root.find_children("*","Button",true,false):
        var control := node as Control
        if control == null:
            continue
        var rect := control.get_global_rect()
        var delta := Vector2.ZERO
        var margin := 8.0
        if rect.position.x < margin:
            delta.x += margin-rect.position.x
        elif rect.end.x > screen.x-margin:
            delta.x -= rect.end.x-(screen.x-margin)
        if rect.position.y < margin:
            delta.y += margin-rect.position.y
        elif rect.end.y > screen.y-margin:
            delta.y -= rect.end.y-(screen.y-margin)
        control.position += delta

func set_mobile_controls_enabled(enabled: bool) -> void:
    touch_ui_enabled = enabled
    # V0.5.23: reativar o HUD não altera a posição salva.
    _apply_touch_visibility()
    if enabled:
        call_deferred("_clamp_mobile_controls_to_screen")

    # Reaplica no próximo frame para vencer re-layout do menu/editor.
    call_deferred("_apply_touch_visibility")

    for car in get_tree().get_nodes_in_group("vehicle"):
        if not is_instance_valid(car):
            continue
        if car.has_method("set_mobile_ui_enabled"):
            car.call("set_mobile_ui_enabled",enabled)
        elif car.has_method("set_mobile_steering_mode"):
            car.set("touch_ui_enabled",enabled)

func _apply_touch_visibility() -> void:
    if touch_root == null:
        return

    var should_show: bool = touch_ui_enabled and vehicle == null
    touch_root.visible = should_show
    if weapon_prev_button != null:
        weapon_prev_button.visible = should_show
    if weapon_next_button != null:
        weapon_next_button.visible = should_show

    # Força os controles do jogador a reaparecerem ao alternar PC -> Celular.
    if joystick != null:
        joystick.visible = should_show
        joystick.mouse_filter = Control.MOUSE_FILTER_STOP if not OS.has_feature("mobile") else Control.MOUSE_FILTER_IGNORE

    for child in touch_root.find_children("*","Button",true,false):
        var button := child as Button
        if button == null:
            continue
        if button == enter_vehicle_button:
            button.visible = should_show and nearby_vehicle != null
        else:
            button.visible = should_show
        # No PC, botões mobile funcionam como preview clicável com o mouse.
        if not OS.has_feature("mobile"):
            button.mouse_filter = Control.MOUSE_FILTER_STOP

    _sync_mouse_capture()

func _update_vehicle_scan(delta: float) -> void:
    vehicle_scan_clock += delta
    if vehicle_scan_clock < 0.12:
        return
    vehicle_scan_clock = 0.0

    if vehicle != null:
        nearby_vehicle = null
        if enter_vehicle_button != null:
            enter_vehicle_button.visible = false
        return

    var best: Node3D = null
    var best_distance: float = 5.5
    for value in get_tree().get_nodes_in_group("vehicle"):
        var candidate := value as Node3D
        if candidate == null or not is_instance_valid(candidate):
            continue
        var current_driver: Variant = candidate.get("driver")
        if current_driver != null:
            continue
        var distance: float = global_position.distance_to(candidate.global_position)
        if distance < best_distance:
            best_distance = distance
            best = candidate

    nearby_vehicle = best
    if enter_vehicle_button != null:
        enter_vehicle_button.visible = touch_ui_enabled and nearby_vehicle != null

func _try_enter_vehicle() -> void:
    if vehicle != null or nearby_vehicle == null or _chat_is_typing():
        return
    if nearby_vehicle.has_method("interact"):
        nearby_vehicle.call("interact", self)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        cancel_combat_input()
        camera_dragging = false
        touch_look_index = -1
        touch_sprint = false

func _request_jump() -> void:
    if vehicle == null and not _chat_is_typing() and not get_tree().paused:
        jump_buffer = .12

func cancel_combat_input() -> void:
    fire_pose_remaining = 0.0
    fire_held = false
    fire_press_pending = false
    semi_auto_pending = false
    aim_trigger_held = false
    aiming = false
    jump_buffer = 0.0
    camera_dragging = false
    touch_look_index = -1
    touch_sprint = false
    camera_recoil = 0.0
    if is_instance_valid(muzzle_flash):
        muzzle_flash.visible = false
    muzzle_time = 0.0
    _update_camera_transform()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _refresh_aim_reticle()

func set_character_fov(value: float) -> void:
    character_fov = clampf(value,58.0,66.0)
    if camera != null and is_instance_valid(camera):
        camera.fov = character_fov

func set_vehicle_fov(value: float) -> void:
    vehicle_fov = clampf(value,66.0,74.0)
    for car in get_tree().get_nodes_in_group("vehicle"):
        if is_instance_valid(car) and car.has_method("set_user_camera_fov"):
            car.call("set_user_camera_fov",vehicle_fov)

func _update_aim_camera(delta: float) -> void:
    camera_recoil *= exp(-delta * 12.0)
    _update_camera_transform()
    camera_aim_weight = lerpf(camera_aim_weight, 1.0 if aim_trigger_held else 0.0, 1.0-exp(-delta*12.0))
    var lateral := Basis(Vector3.UP,cam_yaw) * Vector3(.54*camera_aim_weight,0,0)
    camera_pivot.position = lateral + Vector3(0,lerpf(1.4651,2.34,camera_aim_weight),0)
    spring_arm.spring_length = lerpf(free_camera_distance,2.42,camera_aim_weight)
    camera.fov = lerpf(character_fov,maxf(45.0,character_fov-8.5),camera_aim_weight)
    if aim_reticle != null:
        aim_reticle.set("spread",_weapon_anim_recoil()*150.0 if visual.motion_ready else 0.0)
        aim_reticle.queue_redraw()

func _exit_tree() -> void:
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    damage_method_cache.clear()
    # Libera playbacks ao trocar de cena, mesmo com o gatilho pressionado.
    for audio_node in [gun_audio,reload_audio]:
        if is_instance_valid(audio_node):
            audio_node.stop()
            audio_node.stream = null

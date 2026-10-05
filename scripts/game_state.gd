extends Node
## BR1 v0.4.8 - progresso local + PayDay por 60 minutos realmente jogados.

signal stats_changed
signal game_notice(category: String, text: String)

var selected_gender: String = ""
var selected_server: String = ""
var startup_cache: Dictionary = {}
var prepared_world: Node = null
var is_police: bool = false
var is_medic: bool = false
var is_military: bool = false

var money: int = 2500
var main_coins: int = 0
var level: int = 1
var xp: int = 350

const PAYDAY_INTERVAL_SECONDS: float = 3600.0
const PAYDAY_XP: int = 10
const PAYDAY_UNEMPLOYMENT: int = 1000
const SAVE_PATH := "user://br1_progress_v048.cfg"

var payday_elapsed_seconds: float = 0.0
var save_clock: float = 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _load_progress()

func _process(delta: float) -> void:
    # Pausa do menu e tempo fora do jogo não contam.
    if get_tree().paused:
        return
    if selected_server != "BR1" or selected_gender.is_empty():
        return

    payday_elapsed_seconds += maxf(delta,0.0)
    save_clock += maxf(delta,0.0)

    while payday_elapsed_seconds >= PAYDAY_INTERVAL_SECONDS:
        payday_elapsed_seconds -= PAYDAY_INTERVAL_SECONDS
        _grant_payday()

    if save_clock >= 10.0:
        save_clock = 0.0
        _save_progress()

func reset_payday() -> void:
    payday_elapsed_seconds = 0.0
    _save_progress()

func payday_seconds_remaining() -> float:
    return maxf(0.0,PAYDAY_INTERVAL_SECONDS-payday_elapsed_seconds)

func _grant_payday() -> void:
    var previous_level := level
    money += PAYDAY_UNEMPLOYMENT
    xp += PAYDAY_XP
    while xp >= xp_required():
        xp -= xp_required()
        level += 1
    stats_changed.emit()
    game_notice.emit("PAYDAY","Salário desemprego: +R$ 1.000")
    game_notice.emit("XP","+10 XP • PayDay")
    if level > previous_level:
        game_notice.emit("NÍVEL","Você alcançou o nível %d." % level)
    _save_progress()

func xp_required() -> int:
    return 1000+(level-1)*350

func add_money(amount: int) -> void:
    var previous := money
    money = max(0,money+amount)
    var applied := money-previous
    stats_changed.emit()
    if applied != 0:
        var sign := "+" if applied > 0 else "-"
        game_notice.emit("DINHEIRO","%sR$ %d" % [sign,abs(applied)])
    _save_progress()

func add_main_coins(amount: int) -> void:
    var previous := main_coins
    main_coins = max(0,main_coins+amount)
    var applied := main_coins-previous
    stats_changed.emit()
    if applied != 0:
        var sign := "+" if applied > 0 else "-"
        game_notice.emit("MAIN COINS","%sMC %d" % [sign,abs(applied)])
    _save_progress()

func add_xp(amount: int) -> void:
    var granted := maxi(0,amount)
    var previous_level := level
    xp += granted
    while xp >= xp_required():
        xp -= xp_required()
        level += 1
    stats_changed.emit()
    if granted > 0:
        game_notice.emit("XP","+%d XP" % granted)
    if level > previous_level:
        game_notice.emit("NÍVEL","Você alcançou o nível %d." % level)
    _save_progress()

func _load_progress() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(SAVE_PATH) != OK:
        return
    money = maxi(0,int(cfg.get_value("progress","money",money)))
    main_coins = maxi(0,int(cfg.get_value("progress","main_coins",main_coins)))
    level = maxi(1,int(cfg.get_value("progress","level",level)))
    xp = maxi(0,int(cfg.get_value("progress","xp",xp)))
    payday_elapsed_seconds = clampf(float(cfg.get_value("progress","payday_elapsed_seconds",0.0)),0.0,PAYDAY_INTERVAL_SECONDS-0.001)

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress","money",money)
    cfg.set_value("progress","main_coins",main_coins)
    cfg.set_value("progress","level",level)
    cfg.set_value("progress","xp",xp)
    cfg.set_value("progress","payday_elapsed_seconds",payday_elapsed_seconds)
    cfg.save(SAVE_PATH)

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_progress()

func _exit_tree() -> void:
    _save_progress()

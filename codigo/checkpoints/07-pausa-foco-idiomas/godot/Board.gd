extends Node2D
# Chapter 07: add independent manual/focus pauses and bilingual HUD.
# Input and drawing stay in Godot; rules remain in Rust Game.

const CELL_SIZE: int = 32
const BOARD_COLUMNS: int = 16
const BOARD_ROWS: int = 12
const STEP_SECONDS: float = 0.16

var bridge: SnakeBridge
var elapsed: float = 0.0
var has_started: bool = false
var user_paused: bool = false
var focus_paused: bool = false
var portuguese: bool = false

@onready var status_label: Label = $Status
@onready var help_label: Label = $Help

func _ready() -> void:
    bridge = SnakeBridge.new()
    add_child(bridge)
    _restart()

func _restart() -> void:
    bridge.reset_game()
    has_started = false
    user_paused = false
    elapsed = 0.0
    _update_status()
    queue_redraw()

func _update_status() -> void:
    if bridge == null:
        return
    var score: int = bridge.current_score()
    if bridge.did_win():
        status_label.text = ("Você venceu! Pontos: %d" if portuguese else "You won! Score: %d") % score
    elif bridge.is_game_over():
        status_label.text = ("Fim de jogo! Pontos: %d" if portuguese else "Game over! Score: %d") % score
    elif focus_paused:
        status_label.text = "Sem foco — jogo pausado" if portuguese else "Window unfocused — paused"
    elif user_paused:
        status_label.text = ("Pausado | Pontos: %d" if portuguese else "Paused | Score: %d") % score
    elif not has_started:
        status_label.text = ("Use uma seta para começar | Pontos: %d" if portuguese else "Press an arrow to start | Score: %d") % score
    else:
        status_label.text = ("Pontos: %d" if portuguese else "Score: %d") % score

    help_label.text = (
        "Setas: mover | P/Espaço: pausa | R: reiniciar | L: idioma"
        if portuguese else
        "Arrows: move | P/Space: pause | R: restart | L: language"
    )

func _process(delta: float) -> void:
    if bridge == null or not has_started or user_paused or focus_paused or bridge.is_game_over():
        return
    # Do not catch up a long pause with many unintended logical ticks.
    elapsed += minf(delta, STEP_SECONDS)
    if elapsed >= STEP_SECONDS:
        elapsed -= STEP_SECONDS
        bridge.advance_game()
        _update_status()
        queue_redraw()

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_FOCUS_OUT:
            focus_paused = true
            elapsed = 0.0
            if bridge != null and is_node_ready():
                _update_status()
                queue_redraw()
        NOTIFICATION_APPLICATION_FOCUS_IN:
            focus_paused = false
            elapsed = 0.0
            if bridge != null and is_node_ready():
                _update_status()
                queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return

    match event.keycode:
        KEY_R:
            _restart()
        KEY_P, KEY_SPACE:
            if bridge != null and not bridge.is_game_over():
                user_paused = not user_paused
                elapsed = 0.0
                _update_status()
                queue_redraw()
        KEY_L:
            portuguese = not portuguese
            _update_status()
        KEY_UP:
            if _can_turn():
                bridge.turn_up()
                _begin_if_waiting()
        KEY_DOWN:
            if _can_turn():
                bridge.turn_down()
                _begin_if_waiting()
        KEY_RIGHT:
            if _can_turn():
                bridge.turn_right()
                _begin_if_waiting()
        KEY_LEFT:
            # The initial direction is Right: Left cannot start a reverse move.
            if has_started and _can_turn():
                bridge.turn_left()

func _can_turn() -> bool:
    return bridge != null and not user_paused and not focus_paused and not bridge.is_game_over()

func _begin_if_waiting() -> void:
    if not has_started:
        has_started = true
        elapsed = 0.0
        _update_status()

func _draw() -> void:
    var board_width: float = float(BOARD_COLUMNS * CELL_SIZE)
    var board_height: float = float(BOARD_ROWS * CELL_SIZE)
    draw_rect(
        Rect2(0, 0, board_width, board_height),
        Color(0.09, 0.12, 0.17), true
    )
    for column in range(1, BOARD_COLUMNS):
        var x: float = float(column * CELL_SIZE)
        draw_line(
            Vector2(x, 0), Vector2(x, board_height),
            Color(0.3, 0.4, 0.5), 1.0
        )
    for row in range(1, BOARD_ROWS):
        var y: float = float(row * CELL_SIZE)
        draw_line(
            Vector2(0, y), Vector2(board_width, y),
            Color(0.3, 0.4, 0.5), 1.0
        )

    if bridge == null:
        return

    var cells: Array[Vector2i] = bridge.snake_cells()
    for i in range(cells.size()):
        var cell: Vector2i = cells[i]
        var tint: Color = Color(0.29, 0.72, 0.49)
        if i == 0:
            tint = Color(0.56, 0.95, 0.60)
        draw_rect(
            Rect2(
                cell.x * CELL_SIZE + 2,
                cell.y * CELL_SIZE + 2,
                CELL_SIZE - 4,
                CELL_SIZE - 4
            ),
            tint, true
        )

    var food: Vector2i = bridge.food_cell()
    if food.x >= 0 and food.y >= 0:
        var food_center: Vector2 = Vector2(
            (food.x + 0.5) * CELL_SIZE,
            (food.y + 0.5) * CELL_SIZE
        )
        draw_circle(
            food_center, CELL_SIZE * 0.32,
            Color(0.95, 0.31, 0.29)
        )

    if user_paused or focus_paused or bridge.is_game_over():
        draw_rect(
            Rect2(0, 0, board_width, board_height),
            Color(0.02, 0.03, 0.04, 0.38),
            true
        )

extends Node2D
# Chapter 14: emit score and completion signals; UI listens via a separate HUD.
# Pure Rust rules, SQLite schema and the native bridge are unchanged.

signal score_changed(new_score: int)
signal match_finished(final_score: int, won: bool)
# Input and drawing stay in Godot; rules remain in Rust Game.

const HighScoreStore = preload("res://HighScoreStore.gd")

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
var best_score: int = 0
var completed_recorded: bool = false
var save_failed: bool = false
var history_failed: bool = false
var history_count: int = -1
var match_ticks: int = 0
var ranking_visible: bool = false
var ranking_panel: Panel
var ranking_label: Label
var score_hud: ScoreHud
@export var history_path: String = "user://scores.db"
@export var score_path: String = "user://snake_best_score.txt"

@onready var status_label: Label = $Status
@onready var help_label: Label = $Help

func _ready() -> void:
    bridge = SnakeBridge.new()
    add_child(bridge)
    best_score = HighScoreStore.load_best(score_path)
    history_count = int(bridge.completed_match_count(_absolute_history_path()))
    _build_ranking_panel()
    _build_score_hud()
    _restart()

func _restart() -> void:
    var previous_score: int = bridge.current_score()
    bridge.reset_game()
    if bridge.current_score() != previous_score:
        score_changed.emit(bridge.current_score())
    has_started = false
    user_paused = false
    completed_recorded = false
    match_ticks = 0
    ranking_visible = false
    if ranking_panel != null:
        ranking_panel.visible = false
    save_failed = false
    history_failed = history_count < 0
    elapsed = 0.0
    _update_status()
    queue_redraw()

func _update_status() -> void:
    if bridge == null:
        return
    var score: int = bridge.current_score()
    if bridge.did_win():
        status_label.text = ("Vitória! Pontos: %d | Recorde: %d" if portuguese else "You won! Score: %d | Best: %d") % [score, best_score]
    elif bridge.is_game_over():
        status_label.text = ("Fim! Pontos: %d | Recorde: %d" if portuguese else "Game over! Score: %d | Best: %d") % [score, best_score]
    elif focus_paused:
        status_label.text = ("Sem foco | Recorde: %d" if portuguese else "Unfocused | Best: %d") % best_score
    elif user_paused:
        status_label.text = ("Pausado | Pontos: %d | Recorde: %d" if portuguese else "Paused | Score: %d | Best: %d") % [score, best_score]
    elif not has_started:
        status_label.text = ("Seta para iniciar | Recorde: %d" if portuguese else "Press arrow to start | Best: %d") % best_score
    else:
        status_label.text = ("Pontos: %d | Recorde: %d" if portuguese else "Score: %d | Best: %d") % [score, best_score]

    if history_count >= 0:
        status_label.text += (" | Partidas: %d" if portuguese else " | Matches: %d") % history_count

    if ranking_visible:
        help_label.text = "H: fechar ranking | L: idioma" if portuguese else "H: close ranking | L: language"
    elif history_failed:
        help_label.text = "Histórico SQLite indisponível" if portuguese else "SQLite history unavailable"
    elif save_failed:
        help_label.text = "Falha ao salvar recorde" if portuguese else "Failed to save high score"
    else:
        help_label.text = (
            "Setas: mover | P/Espaço: pausa | R: reiniciar | L: idioma"
            if portuguese else
            "Arrows: move | P/Space: pause | R: restart | L: language"
        )

func _process(delta: float) -> void:
    if bridge == null or not has_started or user_paused or focus_paused or ranking_visible or bridge.is_game_over():
        return
    # Do not catch up a long pause with many unintended logical ticks.
    elapsed += minf(delta, STEP_SECONDS)
    if elapsed >= STEP_SECONDS:
        elapsed -= STEP_SECONDS
        var previous_score: int = bridge.current_score()
        bridge.advance_game()
        match_ticks += 1
        var current_score: int = bridge.current_score()
        if current_score != previous_score:
            score_changed.emit(current_score)
        if bridge.is_game_over():
            _record_completion_once()
            match_finished.emit(current_score, bridge.did_win())
        _update_status()
        queue_redraw()

func _record_completion_once() -> void:
    # A finished match is recorded once, never once per rendered frame.
    if completed_recorded or not bridge.is_game_over():
        return
    completed_recorded = true
    var score: int = bridge.current_score()
    if not bridge.record_completed_match(_absolute_history_path(), score, bridge.did_win(), match_ticks):
        history_failed = true
        push_warning("Could not save completed match to SQLite")
    else:
        history_count = int(bridge.completed_match_count(_absolute_history_path()))
        history_failed = history_count < 0
    if score > best_score:
        if HighScoreStore.save_if_higher(score, score_path):
            best_score = maxi(score, HighScoreStore.load_best(score_path))
        else:
            save_failed = true

func _build_score_hud() -> void:
    # A reusable UI node; connected only once per scene lifetime, not per restart.
    score_hud = ScoreHud.new()
    score_hud.name = "ScoreHud"
    score_hud.position = Vector2(524, 12)
    score_hud.size = Vector2(108, 28)
    add_child(score_hud)
    score_changed.connect(score_hud.show_score)
    score_hud.set_score_language(portuguese)
    score_hud.show_score(bridge.current_score())

func _build_ranking_panel() -> void:
    # The panel is a presentation-only node, not part of the Rust Game.
    ranking_panel = Panel.new()
    ranking_panel.name = "RankingPanel"
    ranking_panel.position = Vector2(116, 16)
    ranking_panel.size = Vector2(280, 356)
    ranking_panel.visible = false
    add_child(ranking_panel)
    ranking_label = Label.new()
    ranking_label.name = "RankingText"
    ranking_label.position = Vector2(16, 12)
    ranking_label.size = Vector2(248, 326)
    ranking_panel.add_child(ranking_label)

func _refresh_ranking() -> void:
    var lines: PackedStringArray = PackedStringArray()
    lines.append("DEZ MELHORES" if portuguese else "TOP TEN SCORES")
    var version: int = int(bridge.history_schema_version(_absolute_history_path()))
    if version >= 0:
        lines.append(("Versão do banco: %d" if portuguese else "Database version: %d") % version)
    lines.append("")
    # [] means zero completed matches; [-1] is a SQLite query error.
    # The Rust schema forbids negative persisted scores.
    var scores: Array = bridge.top_ten_scores(_absolute_history_path())
    if scores.size() == 1 and int(scores[0]) == -1:
        history_failed = true
        lines.append("Histórico indisponível" if portuguese else "History unavailable")
    elif scores.is_empty():
        lines.append("Nenhuma partida concluída" if portuguese else "No completed matches")
    else:
        for index in range(scores.size()):
            lines.append("%d. %d" % [index + 1, scores[index]])
    lines.append("")
    lines.append("H: fechar" if portuguese else "H: close")
    ranking_label.text = "\n".join(lines)

func _toggle_ranking() -> void:
    ranking_visible = not ranking_visible
    ranking_panel.visible = ranking_visible
    elapsed = 0.0
    if ranking_visible:
        _refresh_ranking()
    _update_status()

func _absolute_history_path() -> String:
    return ProjectSettings.globalize_path(history_path)

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
        KEY_H:
            _toggle_ranking()
        KEY_P, KEY_SPACE:
            if bridge != null and not bridge.is_game_over():
                user_paused = not user_paused
                elapsed = 0.0
                _update_status()
                queue_redraw()
        KEY_L:
            portuguese = not portuguese
            score_hud.set_score_language(portuguese)
            if ranking_visible:
                _refresh_ranking()
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
    return bridge != null and not user_paused and not focus_paused and not ranking_visible and not bridge.is_game_over()

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

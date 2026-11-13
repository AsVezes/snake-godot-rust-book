extends SceneTree
const HighScoreStore = preload("res://HighScoreStore.gd")
# Static and simulated integration checks; requires a compiled Rust library.

var failures: Array[String] = []
var checks: int = 0

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)
        push_error("CH16_FAIL: " + description)

func press(board: Node, keycode: Key) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = keycode
    event.pressed = true
    board.call("_unhandled_key_input", event)

func tick(board: Node, seconds: float = 0.16) -> void:
    board.call("_process", seconds)

func _run() -> void:
    var resource: PackedScene = load("res://Main.tscn") as PackedScene
    if resource == null:
        push_error("CH16_FAIL: Main.tscn not loaded")
        quit(1)
        return

    # Isolate the database from the player's real data, BEFORE _ready.
    var test_db: String = "user://checkpoint16_smoke_scores.db"
    var native_db: String = ProjectSettings.globalize_path(test_db)
    if FileAccess.file_exists(test_db):
        DirAccess.remove_absolute(native_db)
    var score_fixture: String = "user://checkpoint16_smoke_player_best.txt"
    var score_fixture_native: String = ProjectSettings.globalize_path(score_fixture)
    if FileAccess.file_exists(score_fixture):
        DirAccess.remove_absolute(score_fixture_native)
    var board: Node = resource.instantiate()
    board.set("history_path", test_db)
    board.set("score_path", score_fixture)
    root.add_child(board)
    # Connect an isolated recorder; never change the original persistence fixtures.
    var recorder = preload("res://SignalRecorder.gd").new()
    check(board.has_signal("score_changed"), "score change signal declared")
    check(board.has_signal("match_finished"), "match completion signal declared")
    board.connect("score_changed", Callable(recorder, "on_score_changed"))
    board.connect("match_finished", Callable(recorder, "on_match_finished"))
    var hud: Label = board.get_node_or_null("ScoreHud") as Label
    check(hud != null, "score HUD exists and is a Label")
    if hud != null:
        check(hud.text == "Score: 0", "HUD initializes from current state")
    var game: SnakeBridge = board.get("bridge") as SnakeBridge
    check(game != null, "native SnakeBridge exists")
    if game == null:
        quit(1)
        return
    var status: Label = board.get_node_or_null("Status") as Label
    var help: Label = board.get_node_or_null("Help") as Label
    check(status != null, "Status node exists")
    check(help != null, "Help node exists")
    if status == null or help == null:
        quit(1)
        return

    check(game.current_score() == 0, "initial score zero")
    check(game.snake_cells().size() == 3, "initial length three")
    check(game.snake_cells()[0] == Vector2i(8, 6), "borrowed GameView exposes the same head")
    check(game.food_cell() == Vector2i(11, 6), "borrowed GameView exposes initial food")
    check(not board.get("has_started"), "start waits for arrow")
    check(status.text.contains("Press arrow to start") and status.text.contains("Best:"), "English start hint and persistent best score")
    check(help.text.contains("Arrows:"), "initial English controls")
    check(board.get("history_count") == 0, "fresh history empty")
    check(game.top_ten_scores(native_db).is_empty(), "fresh empty ranking succeeds")
    check(status.text.contains("Matches: 0"), "English history label")
    var start_head: Vector2i = game.snake_cells()[0]
    tick(board, 1.0)
    check(game.snake_cells()[0] == start_head, "no movement before first arrow")

    press(board, KEY_L)
    check(board.get("portuguese"), "language switched to Portuguese")
    if hud != null:
        check(hud.text == "Pontos: 0", "HUD language follows board")
    check(status.text.contains("Seta para iniciar") and status.text.contains("Recorde:"), "Portuguese start hint and persistent record")
    check(help.text.contains("Setas:"), "Portuguese help")
    check(status.text.contains("Partidas: 0"), "Portuguese history label")
    press(board, KEY_P)
    check(board.get("user_paused"), "P pauses")
    press(board, KEY_UP)
    check(not board.get("has_started"), "cannot start while manually paused")
    press(board, KEY_P)
    check(not board.get("user_paused"), "P resumes")

    press(board, KEY_LEFT)
    check(not board.get("has_started"), "left does not reverse initial snake")
    press(board, KEY_RIGHT)
    check(board.get("has_started"), "right starts game")
    tick(board)
    var first_head: Vector2i = game.snake_cells()[0]
    check(first_head == start_head + Vector2i(1, 0), "one logical tick")
    check(game.current_score() == 0 and game.food_cell() == Vector2i(11, 6), "borrowed view reads one consistent completed tick")

    press(board, KEY_SPACE)
    check(board.get("user_paused"), "space pauses")
    tick(board, 1.0)
    check(game.snake_cells()[0] == first_head, "manual pause freezes motion")
    press(board, KEY_SPACE)
    check(not board.get("user_paused"), "space resumes")

    # Simulate the application-level notification without changing OS focus.
    board.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    check(board.get("focus_paused"), "focus out activates automatic pause")
    tick(board, 1.0)
    check(game.snake_cells()[0] == first_head, "focus out freezes motion")
    press(board, KEY_DOWN)
    check(game.snake_cells()[0] == first_head, "direction while unfocused is ignored")
    board.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    check(not board.get("focus_paused"), "focus in clears automatic pause")
    tick(board)
    check(game.snake_cells()[0] == first_head + Vector2i(1, 0), "focus return allows next tick")

    press(board, KEY_P)
    check(board.get("user_paused"), "manual pause activated before focus cycle")
    board.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    board.call("_notification", Node.NOTIFICATION_APPLICATION_FOCUS_IN)
    check(board.get("user_paused"), "manual pause survives focus loss and return")
    tick(board, 1.0)
    check(game.snake_cells()[0] == first_head + Vector2i(1, 0), "manual pause still blocks ticks")
    press(board, KEY_P)
    check(not board.get("user_paused"), "manual pause can be released after focus cycle")

    press(board, KEY_R)
    check(game.current_score() == 0, "R resets score")
    check(recorder.score_values.is_empty(), "reset of zero emits no redundant score event")
    check(not board.get("has_started"), "R waits for new direction")
    check(not board.get("user_paused"), "R clears manual pause")
    check(board.get("portuguese"), "R preserves language preference")
    tick(board, 1.0)
    check(game.snake_cells()[0] == start_head, "R prevents auto-start")
    press(board, KEY_L)
    check(not board.get("portuguese"), "L switches back to English")
    if hud != null:
        check(hud.text == "Score: 0", "HUD switches back to English")
    press(board, KEY_RIGHT)
    for i in range(3):
        tick(board)
    check(game.current_score() == 1, "first food increases score")
    check(game.snake_cells()[0] == Vector2i(11, 6), "baseline test scenario has expected first food cell")
    check(recorder.score_values == [1], "one score event on first food")
    if hud != null:
        check(hud.text == "Score: 1", "score signal updates HUD once")
    check(game.snake_cells().size() == 4, "eating grows the snake")
    check(status.text.contains("Score: 1"), "HUD reports score after eating")

    # Use a separate temporary path: never change the player's real record.
    var test_path: String = "user://checkpoint16_smoke_record.txt"
    var absolute_path: String = ProjectSettings.globalize_path(test_path)
    if FileAccess.file_exists(test_path):
        DirAccess.remove_absolute(absolute_path)
    check(HighScoreStore.load_best(test_path) == 0, "missing file starts at zero")
    check(HighScoreStore.save_if_higher(17, test_path), "first high score can be saved")
    check(HighScoreStore.load_best(test_path) == 17, "high score is loaded from disk")
    check(HighScoreStore.save_if_higher(7, test_path), "lower score is ignored successfully")
    check(HighScoreStore.load_best(test_path) == 17, "lower score does not overwrite record")
    check(not HighScoreStore.save_if_higher(-1, test_path), "negative scores rejected")
    var corrupted: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
    if corrupted != null:
        corrupted.store_string("not a score")
        corrupted.close()
        check(HighScoreStore.load_best(test_path) == 0, "corrupted file falls back safely")
        check(HighScoreStore.save_if_higher(5, test_path), "corrupted data can be replaced")
        check(HighScoreStore.load_best(test_path) == 5, "recovered record is readable")
    else:
        check(false, "fixture file opens for corruption test")
    check(DirAccess.remove_absolute(absolute_path) == OK, "temporary high-score file removed")

    check(game.record_completed_match(native_db, 3, false, 12), "records a loss")
    check(game.record_completed_match(native_db, 7, true, 21), "records a win")
    check(game.completed_match_count(native_db) == 2, "two matches saved")
    check(game.history_schema_version(native_db) == 2, "database schema upgraded to v2")
    var backup_file: String = "user://checkpoint16_smoke_backup.db"
    var backup_native: String = ProjectSettings.globalize_path(backup_file)
    if FileAccess.file_exists(backup_file):
        DirAccess.remove_absolute(backup_native)
    check(game.backup_completed_matches(native_db, backup_native), "backup requested explicitly succeeds")
    check(game.completed_match_count(backup_native) == 2, "backup includes both stored matches")
    check(DirAccess.remove_absolute(backup_native) == OK, "temporary backup removed")
    check(not game.record_completed_match(native_db, 2, true, -1), "negative tick count rejected")
    check(not game.record_completed_match(native_db, -1, false, 1), "rejects negative scores")
    check(game.completed_match_count(native_db) == 2, "invalid input does not write")
    var top_two: Array = game.top_ten_scores(native_db)
    check(top_two.size() == 2, "ranking includes the two stored matches")
    if top_two.size() == 2:
        check(top_two[0] == 7 and top_two[1] == 3, "ranking sorts scores descending")

    var rank_panel: Panel = board.get_node_or_null("RankingPanel") as Panel
    var rank_text: Label = board.get_node_or_null("RankingPanel/RankingText") as Label
    check(rank_panel != null and rank_text != null, "ranking panel exists")
    if rank_panel != null and rank_text != null:
        check(not rank_panel.visible, "ranking is hidden by default")
        press(board, KEY_H)
        check(board.get("ranking_visible") and rank_panel.visible, "H opens the ranking")
        check(rank_text.text.contains("1. 7") and rank_text.text.contains("2. 3"), "ranked scores are visible")
        check(rank_text.text.contains("Database version: 2"), "ranking shows SQLite schema version")
        var held_head: Vector2i = game.snake_cells()[0]
        tick(board, 1.0)
        check(game.snake_cells()[0] == held_head, "ranking blocks movement")
        press(board, KEY_L)
        check(rank_text.text.contains("DEZ MELHORES"), "ranking heading translated")
        press(board, KEY_L)
        press(board, KEY_H)
        check(not rank_panel.visible and not board.get("ranking_visible"), "H closes ranking")
    var second_bridge: SnakeBridge = SnakeBridge.new()
    root.add_child(second_bridge)
    check(second_bridge.completed_match_count(native_db) == 2, "new connection sees saved rows")
    second_bridge.queue_free()

    press(board, KEY_R)
    check(recorder.score_values == [1, 0], "reset from one point emits one score event")
    if hud != null:
        check(hud.text == "Score: 0", "HUD resets without another subscription")
    press(board, KEY_UP)
    for i in range(16):
        tick(board)
    check(game.is_game_over(), "wall collision ends game")
    check(recorder.finished_games.size() == 1, "exactly one completion signal")
    if recorder.finished_games.size() == 1:
        check(recorder.finished_games[0]["score"] == 0, "completion reports actual score")
        check(not recorder.finished_games[0]["won"], "completion reports loss")
    check(game.completed_match_count(native_db) == 3, "Board records completed match")
    board.call("_record_completion_once")
    tick(board, 1.0)
    check(game.completed_match_count(native_db) == 3, "later frames do not duplicate match")
    check(recorder.finished_games.size() == 1, "extra frames never duplicate completion event")
    check(board.get("history_count") == 3, "HUD count refreshes")
    check(game.history_schema_version(native_db) == 2, "migrated SQLite version equals two")
    check(board.get("match_ticks") > 0, "completed game counts logical ticks")
    var latest_rank: Array = game.top_ten_scores(native_db)
    check(latest_rank.size() == 3, "completed match appears in ranking")
    check(latest_rank[0] == 7, "leading score still first")

    var bad_db: String = "user://checkpoint16_smoke_corrupt.db"
    var bad_native: String = ProjectSettings.globalize_path(bad_db)
    if FileAccess.file_exists(bad_db):
        DirAccess.remove_absolute(bad_native)
    var corrupt: FileAccess = FileAccess.open(bad_db, FileAccess.WRITE)
    if corrupt != null:
        corrupt.store_string("not a SQLite database")
        corrupt.close()
        check(game.completed_match_count(bad_native) == -1, "corrupt SQL file reported")
        var bad_scores: Array = game.top_ten_scores(bad_native)
        check(bad_scores.size() == 1 and bad_scores[0] == -1, "ranking failure marker is not an empty result")
        board.set("history_path", bad_db)
        press(board, KEY_H)
        var error_label: Label = board.get_node_or_null("RankingPanel/RankingText") as Label
        check(error_label != null, "ranking panel label survives SQLite error")
        if error_label != null:
            check(
                error_label.text.contains("History unavailable") or error_label.text.contains("Histórico indisponível"),
                "ranking displays a database error"
            )
            check(
                not error_label.text.contains("No completed matches") and not error_label.text.contains("Nenhuma partida concluída"),
                "ranking error is never displayed as zero completed matches"
            )
        press(board, KEY_H)
        board.set("history_path", test_db)
        check(not game.record_completed_match(bad_native, 2, false, 1), "corrupt SQL file not overwritten")
        check(DirAccess.remove_absolute(bad_native) == OK, "corrupt SQL fixture removed")
    else:
        check(false, "corrupt SQL fixture can be created")
    check(DirAccess.remove_absolute(native_db) == OK, "isolated SQL history removed")
    if FileAccess.file_exists(score_fixture):
        check(DirAccess.remove_absolute(score_fixture_native) == OK, "isolated high-score fixture removed")
    board.queue_free()
    if failures.is_empty():
        print("CHECKPOINT_16_SMOKE_OK: %d checks" % checks)
        quit(0)
    else:
        push_error("CHECKPOINT_16_SMOKE_FAILED: %d/%d" % [failures.size(), checks])
        quit(1)

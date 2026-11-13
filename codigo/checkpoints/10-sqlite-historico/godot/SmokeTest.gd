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
        push_error("CH10_FAIL: " + description)

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
        push_error("CH10_FAIL: Main.tscn not loaded")
        quit(1)
        return

    # Isolate the database from the player's real data, BEFORE _ready.
    var test_db: String = "user://checkpoint10_smoke_scores.db"
    var native_db: String = ProjectSettings.globalize_path(test_db)
    if FileAccess.file_exists(test_db):
        DirAccess.remove_absolute(native_db)
    var score_fixture: String = "user://checkpoint10_smoke_player_best.txt"
    var score_fixture_native: String = ProjectSettings.globalize_path(score_fixture)
    if FileAccess.file_exists(score_fixture):
        DirAccess.remove_absolute(score_fixture_native)
    var board: Node = resource.instantiate()
    board.set("history_path", test_db)
    board.set("score_path", score_fixture)
    root.add_child(board)
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
    check(not board.get("has_started"), "start waits for arrow")
    check(status.text.contains("Press arrow to start") and status.text.contains("Best:"), "English start hint and persistent best score")
    check(help.text.contains("Arrows:"), "initial English controls")
    check(board.get("history_count") == 0, "fresh history empty")
    check(status.text.contains("Matches: 0"), "English history label")
    var start_head: Vector2i = game.snake_cells()[0]
    tick(board, 1.0)
    check(game.snake_cells()[0] == start_head, "no movement before first arrow")

    press(board, KEY_L)
    check(board.get("portuguese"), "language switched to Portuguese")
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
    check(not board.get("has_started"), "R waits for new direction")
    check(not board.get("user_paused"), "R clears manual pause")
    check(board.get("portuguese"), "R preserves language preference")
    tick(board, 1.0)
    check(game.snake_cells()[0] == start_head, "R prevents auto-start")
    press(board, KEY_L)
    check(not board.get("portuguese"), "L switches back to English")
    press(board, KEY_RIGHT)
    for i in range(3):
        tick(board)
    check(game.current_score() == 1, "first food increases score")
    check(game.snake_cells().size() == 4, "eating grows the snake")
    check(status.text.contains("Score: 1"), "HUD reports score after eating")

    # Use a separate temporary path: never change the player's real record.
    var test_path: String = "user://checkpoint09_smoke_record.txt"
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

    check(game.record_completed_match(native_db, 3, false), "records a loss")
    check(game.record_completed_match(native_db, 7, true), "records a win")
    check(game.completed_match_count(native_db) == 2, "two matches saved")
    check(not game.record_completed_match(native_db, -1, false), "rejects negative scores")
    check(game.completed_match_count(native_db) == 2, "invalid input does not write")
    var second_bridge: SnakeBridge = SnakeBridge.new()
    root.add_child(second_bridge)
    check(second_bridge.completed_match_count(native_db) == 2, "new connection sees saved rows")
    second_bridge.queue_free()

    press(board, KEY_R)
    press(board, KEY_UP)
    for i in range(16):
        tick(board)
    check(game.is_game_over(), "wall collision ends game")
    check(game.completed_match_count(native_db) == 3, "Board records completed match")
    board.call("_record_completion_once")
    tick(board, 1.0)
    check(game.completed_match_count(native_db) == 3, "later frames do not duplicate match")
    check(board.get("history_count") == 3, "HUD count refreshes")

    var bad_db: String = "user://checkpoint10_smoke_corrupt.db"
    var bad_native: String = ProjectSettings.globalize_path(bad_db)
    if FileAccess.file_exists(bad_db):
        DirAccess.remove_absolute(bad_native)
    var corrupt: FileAccess = FileAccess.open(bad_db, FileAccess.WRITE)
    if corrupt != null:
        corrupt.store_string("not a SQLite database")
        corrupt.close()
        check(game.completed_match_count(bad_native) == -1, "corrupt SQL file reported")
        check(not game.record_completed_match(bad_native, 2, false), "corrupt SQL file not overwritten")
        check(DirAccess.remove_absolute(bad_native) == OK, "corrupt SQL fixture removed")
    else:
        check(false, "corrupt SQL fixture can be created")
    check(DirAccess.remove_absolute(native_db) == OK, "isolated SQL history removed")
    if FileAccess.file_exists(score_fixture):
        check(DirAccess.remove_absolute(score_fixture_native) == OK, "isolated high-score fixture removed")
    board.queue_free()
    if failures.is_empty():
        print("CHECKPOINT_10_SMOKE_OK: %d checks" % checks)
        quit(0)
    else:
        push_error("CHECKPOINT_10_SMOKE_FAILED: %d/%d" % [failures.size(), checks])
        quit(1)

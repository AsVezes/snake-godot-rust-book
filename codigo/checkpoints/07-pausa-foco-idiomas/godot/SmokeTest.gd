extends SceneTree
# Static and simulated integration checks; requires a compiled Rust library.

var failures: Array[String] = []
var checks: int = 0

func _init() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)
        push_error("CH07_FAIL: " + description)

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
        push_error("CH07_FAIL: Main.tscn not loaded")
        quit(1)
        return

    var board: Node = resource.instantiate()
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
    check(status.text.contains("Press an arrow"), "initial English hint")
    check(help.text.contains("Arrows:"), "initial English controls")
    var start_head: Vector2i = game.snake_cells()[0]
    tick(board, 1.0)
    check(game.snake_cells()[0] == start_head, "no movement before first arrow")

    press(board, KEY_L)
    check(board.get("portuguese"), "language switched to Portuguese")
    check(status.text.contains("Pontos:"), "Portuguese status")
    check(help.text.contains("Setas:"), "Portuguese help")
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

    board.queue_free()
    if failures.is_empty():
        print("CHECKPOINT_07_SMOKE_OK: %d checks" % checks)
        quit(0)
    else:
        push_error("CHECKPOINT_07_SMOKE_FAILED: %d/%d" % [failures.size(), checks])
        quit(1)

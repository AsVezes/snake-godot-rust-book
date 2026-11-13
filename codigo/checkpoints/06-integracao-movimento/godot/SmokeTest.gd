extends SceneTree
# Run after building Rust and importing the checkpoint Godot project:
# godot --headless --path godot --script res://SmokeTest.gd

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_check_game")

func check(condition: bool, description: String) -> void:
    if not condition:
        failures.append(description)
        push_error("CH06_FAIL: " + description)

func _check_game() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    if scene == null:
        push_error("CH06_FAIL: scene missing")
        quit(1)
        return
    var board: Node = scene.instantiate()
    root.add_child(board)

    var game: SnakeBridge = board.get("bridge") as SnakeBridge
    check(game != null, "Native SnakeBridge should be instantiated")
    if game == null:
        quit(1)
        return
    check(game.snake_cells().size() == 3, "Start with 3 segments")
    check(game.food_cell() == Vector2i(11, 6), "Initial food")

    var head: Vector2i = game.snake_cells()[0]
    board.call("_process", 1.0)
    check(game.snake_cells()[0] == head, "Wait for user to start")

    var key: InputEventKey = InputEventKey.new()
    key.keycode = KEY_RIGHT
    key.pressed = true
    board.call("_unhandled_key_input", key)
    for i in range(3):
        board.call("_process", 0.16)
    check(game.current_score() == 1, "Score after first food")
    check(game.snake_cells().size() == 4, "Growth")

    var restart: InputEventKey = InputEventKey.new()
    restart.keycode = KEY_R
    restart.pressed = true
    board.call("_unhandled_key_input", restart)
    check(game.current_score() == 0, "Restart clears score")
    check(not board.get("has_started"), "Restart waits for input")

    board.queue_free()
    if failures.is_empty():
        print("CHECKPOINT_06_SMOKE_OK")
        quit(0)
    else:
        quit(1)

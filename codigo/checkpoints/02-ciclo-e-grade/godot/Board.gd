extends Node2D
# Chapter 2: the board is drawn by Godot; the snake does not exist yet.

const CELL_SIZE: int = 32
const BOARD_COLUMNS: int = 16
const BOARD_ROWS: int = 12

var seconds_elapsed: float = 0.0

@onready var status_label: Label = $Status

func _ready() -> void:
    status_label.text = "Godot is ready!"
    queue_redraw()

func _process(delta: float) -> void:
    seconds_elapsed += delta
    # A visible effect proves that _process runs continuously.
    status_label.text = "Running: %.1f s" % seconds_elapsed

func _draw() -> void:
    var width: float = BOARD_COLUMNS * CELL_SIZE
    var height: float = BOARD_ROWS * CELL_SIZE
    draw_rect(Rect2(0, 0, width, height), Color(0.09, 0.12, 0.17), true)
    for column in range(1, BOARD_COLUMNS):
        var x: float = column * CELL_SIZE
        draw_line(Vector2(x, 0), Vector2(x, height), Color(0.3, 0.4, 0.5), 1.0)
    for row in range(1, BOARD_ROWS):
        var y: float = row * CELL_SIZE
        draw_line(Vector2(0, y), Vector2(width, y), Color(0.3, 0.4, 0.5), 1.0)

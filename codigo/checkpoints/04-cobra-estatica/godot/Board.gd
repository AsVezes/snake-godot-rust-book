extends Node2D
# Checkpoint 04: Godot renders the snake and food; Rust supplies positions.
# The objects are intentionally static until we introduce Game::tick.

const CELL_SIZE: int = 32
const BOARD_COLUMNS: int = 16
const BOARD_ROWS: int = 12

var bridge: SnakeBridge

@onready var status_label: Label = $Status
@onready var help_label: Label = $Help

func _ready() -> void:
    bridge = SnakeBridge.new()
    add_child(bridge)
    status_label.text = "Score: %d" % bridge.current_score()
    help_label.text = bridge.message()
    queue_redraw()

func _draw() -> void:
    var board_width: float = BOARD_COLUMNS * CELL_SIZE
    var board_height: float = BOARD_ROWS * CELL_SIZE
    draw_rect(
        Rect2(0, 0, board_width, board_height),
        Color(0.09, 0.12, 0.17), true
    )

    for column in range(1, BOARD_COLUMNS):
        var x: float = column * CELL_SIZE
        draw_line(
            Vector2(x, 0), Vector2(x, board_height),
            Color(0.3, 0.4, 0.5), 1.0
        )
    for row in range(1, BOARD_ROWS):
        var y: float = row * CELL_SIZE
        draw_line(
            Vector2(0, y), Vector2(board_width, y),
            Color(0.3, 0.4, 0.5), 1.0
        )

    if bridge == null:
        return

    # The native bridge returns a typed collection of logical cell coordinates.
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
    var food_center: Vector2 = Vector2(
        (food.x + 0.5) * CELL_SIZE,
        (food.y + 0.5) * CELL_SIZE
    )
    draw_circle(food_center, CELL_SIZE * 0.32, Color(0.95, 0.31, 0.29))

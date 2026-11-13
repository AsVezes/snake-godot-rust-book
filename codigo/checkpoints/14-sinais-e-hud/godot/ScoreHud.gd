class_name ScoreHud
extends Label
# Presentation-only: responds to score events and language changes.
# It never advances Game or writes SQLite.

var displayed_score: int = 0
var portuguese: bool = false

func show_score(new_score: int) -> void:
    displayed_score = new_score
    _refresh_text()

func set_score_language(use_portuguese: bool) -> void:
    portuguese = use_portuguese
    _refresh_text()

func _refresh_text() -> void:
    text = ("Pontos: %d" if portuguese else "Score: %d") % displayed_score

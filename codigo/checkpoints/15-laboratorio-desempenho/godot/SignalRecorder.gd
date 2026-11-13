extends RefCounted
# Test helper: records signal notifications without accessing the database.

var score_values: Array[int] = []
var finished_games: Array[Dictionary] = []

func on_score_changed(new_score: int) -> void:
    score_values.append(new_score)

func on_match_finished(final_score: int, won: bool) -> void:
    finished_games.append({"score": final_score, "won": won})

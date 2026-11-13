extends RefCounted
# Checkpoint 09: one high-score integer persisted in Godot's user:// folder.

const SAVE_PATH: String = "user://snake_best_score.txt"

static func load_best(path: String = SAVE_PATH) -> int:
    if not FileAccess.file_exists(path):
        return 0

    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_warning("Cannot open high score: %s" % error_string(FileAccess.get_open_error()))
        return 0

    var raw: String = file.get_as_text().strip_edges()
    file.close()
    if not raw.is_valid_int():
        push_warning("Invalid high-score file; starting at zero")
        return 0
    return maxi(raw.to_int(), 0)

static func save_if_higher(score: int, path: String = SAVE_PATH) -> bool:
    if score < 0:
        return false
    if score <= load_best(path):
        return true

    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_warning("Cannot save high score: %s" % error_string(FileAccess.get_open_error()))
        return false
    file.store_string(str(score))
    var write_error: Error = file.get_error()
    file.close()
    return write_error == OK

//! Checkpoint 12: versioned SQLite migration; Game still owns pure Snake rules.
//! All rules still live in game.rs; this file converts Godot API types.

pub mod game;
mod score_store;

use score_store::ScoreStore;

use game::{Direction, Game, Phase};
use godot::classes::{INode, Node};
use godot::prelude::*;

struct FirstExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FirstExtension {}

#[derive(GodotClass)]
#[class(base=Node)]
struct SnakeBridge {
    game: Game,
    base: Base<Node>,
}

#[godot_api]
impl INode for SnakeBridge {
    fn init(base: Base<Node>) -> Self {
        Self {
            game: Game::new(16, 12),
            base,
        }
    }
}

#[godot_api]
impl SnakeBridge {
    #[func]
    fn message(&self) -> GString {
        "Arrows: move | R: restart".into()
    }

    #[func]
    fn reset_game(&mut self) {
        self.game.reset();
    }

    #[func]
    fn advance_game(&mut self) {
        self.game.tick();
    }

    #[func]
    fn turn_up(&mut self) {
        self.game.turn(Direction::Up);
    }

    #[func]
    fn turn_down(&mut self) {
        self.game.turn(Direction::Down);
    }

    #[func]
    fn turn_left(&mut self) {
        self.game.turn(Direction::Left);
    }

    #[func]
    fn turn_right(&mut self) {
        self.game.turn(Direction::Right);
    }

    #[func]
    fn snake_cells(&self) -> Array<Vector2i> {
        let mut result = Array::new();
        for cell in self.game.segments() {
            result.push(Vector2i::new(cell.x, cell.y));
        }
        result
    }

    #[func]
    fn food_cell(&self) -> Vector2i {
        match self.game.food() {
            Some(cell) => Vector2i::new(cell.x, cell.y),
            None => Vector2i::new(-1, -1),
        }
    }

    #[func]
    fn current_score(&self) -> i32 {
        self.game.score() as i32
    }

    #[func]
    fn is_game_over(&self) -> bool {
        self.game.phase() != Phase::Running
    }

    /// Called only when the Board sees a completed match.
    #[func]
    fn record_completed_match(
        &self,
        absolute_path: GString,
        score: i32,
        won: bool,
        duration_ticks: i32,
    ) -> bool {
        let path = absolute_path.to_string();
        ScoreStore::open(&path)
            .and_then(|store| store.record_completed(score, won, duration_ticks))
            .is_ok()
    }

    /// -1 communicates a database failure without stopping gameplay.
    #[func]
    fn completed_match_count(&self, absolute_path: GString) -> i64 {
        let path = absolute_path.to_string();
        ScoreStore::open(&path)
            .and_then(|store| store.count_matches())
            .unwrap_or(-1)
    }

    /// Contract: [] is an empty ranking; [-1] means a query failure.
    /// Valid scores are nonnegative (matches.score CHECK constraint).
    #[func]
    fn top_ten_scores(&self, absolute_path: GString) -> Array<i64> {
        let mut result = Array::new();
        let query =
            ScoreStore::open(&absolute_path.to_string()).and_then(|store| store.top_ten_scores());
        match query {
            Ok(scores) => {
                for score in scores {
                    result.push(score);
                }
            }
            Err(_) => result.push(-1),
        }
        result
    }

    /// Explicit request only: never back up the user's history on each frame.
    #[func]
    fn backup_completed_matches(&self, source: GString, destination: GString) -> bool {
        ScoreStore::open(&source.to_string())
            .and_then(|store| store.backup_to(&destination.to_string()))
            .is_ok()
    }

    /// -1 means the schema cannot be safely opened or read.
    #[func]
    fn history_schema_version(&self, absolute_path: GString) -> i64 {
        ScoreStore::open(&absolute_path.to_string())
            .and_then(|store| store.schema_version())
            .unwrap_or(-1)
    }

    #[func]
    fn did_win(&self) -> bool {
        self.game.phase() == Phase::Won
    }
}

//! Checkpoint 06: a Godot node owns the pure Rust Game.
//! All rules still live in game.rs; this file converts Godot API types.

pub mod game;

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

    #[func]
    fn did_win(&self) -> bool {
        self.game.phase() == Phase::Won
    }
}

//! Checkpoint 04: Godot draws, Rust supplies logical positions.
//! The snake is static at this stage; movement comes later.

use godot::classes::{INode, Node};
use godot::prelude::*;

struct FirstExtension;

#[gdextension]
unsafe impl ExtensionLibrary for FirstExtension {}

#[derive(GodotClass)]
#[class(base=Node)]
struct SnakeBridge {
    base: Base<Node>,
}

#[godot_api]
impl INode for SnakeBridge {
    fn init(base: Base<Node>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl SnakeBridge {
    #[func]
    fn message(&self) -> GString {
        "Chapter 4: Rust data, Godot drawing".into()
    }

    #[func]
    fn current_score(&self) -> i32 {
        0
    }

    #[func]
    fn snake_cells(&self) -> Array<Vector2i> {
        let mut cells = Array::new();
        cells.push(Vector2i::new(8, 6));
        cells.push(Vector2i::new(7, 6));
        cells.push(Vector2i::new(6, 6));
        cells
    }

    #[func]
    fn food_cell(&self) -> Vector2i {
        Vector2i::new(11, 6)
    }
}

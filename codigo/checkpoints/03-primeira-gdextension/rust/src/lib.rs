//! First chapter where Rust participates in the Godot project.
//! This is not yet the Snake game logic: it only proves the native bridge works.

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
        "Hello from Rust!".into()
    }
}

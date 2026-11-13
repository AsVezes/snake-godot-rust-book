//! Final reference implementation of the optional Rust Preparations R1 and R2.
//!
//! Readers should first perform the incremental exercises independently.
//! This standalone crate has no Godot dependency and no external crates.
use std::collections::VecDeque;

/// A logical grid cell, not a pixel coordinate.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Cell {
    pub x: i32,
    pub y: i32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Up,
    Down,
    Left,
    Right,
}

impl Direction {
    pub fn delta(self) -> (i32, i32) {
        match self {
            Self::Up => (0, -1),
            Self::Down => (0, 1),
            Self::Left => (-1, 0),
            Self::Right => (1, 0),
        }
    }

    /// Exercise R1: check an enum without arbitrary strings or magic numbers.
    pub fn is_vertical(self) -> bool {
        matches!(self, Self::Up | Self::Down)
    }
}

pub fn moved(cell: Cell, direction: Direction) -> Cell {
    let (dx, dy) = direction.delta();
    Cell {
        x: cell.x + dx,
        y: cell.y + dy,
    }
}

/// Exercise R1: the upper and right limits are exclusive.
pub fn is_inside(cell: Cell, width: i32, height: i32) -> bool {
    cell.x >= 0 && cell.y >= 0 && cell.x < width && cell.y < height
}

/// A small collection exercise, deliberately NOT the complete Snake model.
pub struct LabSnake {
    body: VecDeque<Cell>,
    food: Option<Cell>,
}

impl LabSnake {
    pub fn new() -> Self {
        Self {
            body: VecDeque::from([
                Cell { x: 8, y: 6 },
                Cell { x: 7, y: 6 },
                Cell { x: 6, y: 6 },
            ]),
            food: Some(Cell { x: 11, y: 6 }),
        }
    }

    pub fn head(&self) -> Option<&Cell> {
        self.body.front()
    }

    pub fn advance_right(&mut self) {
        let current = *self.body.front().expect("snake is never empty");
        let next = moved(current, Direction::Right);
        self.body.pop_back();
        self.body.push_front(next);
    }

    pub fn food(&self) -> Option<Cell> {
        self.food
    }

    /// Exercise R2: movement does not imply growth.
    pub fn length(&self) -> usize {
        self.body.len()
    }
}

impl Default for LabSnake {
    fn default() -> Self {
        Self::new()
    }
}

pub fn parse_score(raw: &str) -> Result<u32, std::num::ParseIntError> {
    raw.parse::<u32>()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn moving_up_decreases_y_without_mutating_input() {
        let original = Cell { x: 8, y: 6 };
        assert_eq!(moved(original, Direction::Up), Cell { x: 8, y: 5 });
        assert_eq!(original, Cell { x: 8, y: 6 });
    }

    #[test]
    fn moving_right_increases_x() {
        assert_eq!(
            moved(Cell { x: 8, y: 6 }, Direction::Right),
            Cell { x: 9, y: 6 }
        );
    }

    #[test]
    fn vertical_direction_matches_only_up_and_down() {
        assert!(Direction::Up.is_vertical());
        assert!(Direction::Down.is_vertical());
        assert!(!Direction::Left.is_vertical());
        assert!(!Direction::Right.is_vertical());
    }

    #[test]
    fn board_bounds_exclude_negative_and_upper_limits() {
        assert!(is_inside(Cell { x: 15, y: 11 }, 16, 12));
        assert!(is_inside(Cell { x: 0, y: 0 }, 16, 12));
        assert!(!is_inside(Cell { x: 16, y: 11 }, 16, 12));
        assert!(!is_inside(Cell { x: 15, y: 12 }, 16, 12));
        assert!(!is_inside(Cell { x: -1, y: 0 }, 16, 12));
        assert!(!is_inside(Cell { x: 0, y: -1 }, 16, 12));
    }

    #[test]
    fn head_moves_one_cell_right() {
        let mut snake = LabSnake::new();
        snake.advance_right();
        assert_eq!(snake.head(), Some(&Cell { x: 9, y: 6 }));
    }

    #[test]
    fn food_is_optional() {
        assert_eq!(LabSnake::new().food(), Some(Cell { x: 11, y: 6 }));
    }

    #[test]
    fn parsing_reports_errors() {
        assert_eq!(parse_score("7").unwrap(), 7);
        assert!(parse_score("seven").is_err());
        assert!(parse_score("-1").is_err());
    }

    #[test]
    fn body_keeps_three_segments_after_a_normal_step() {
        let mut snake = LabSnake::new();
        assert_eq!(snake.length(), 3);
        snake.advance_right();
        assert_eq!(snake.length(), 3);
    }
}

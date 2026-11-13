//! SQLite persistence is infrastructure, not part of the movement rules.
//! Open connections for history operations, never for game ticks.

use rusqlite::{params, Connection, Result};

pub struct ScoreStore {
    connection: Connection,
}

impl ScoreStore {
    pub fn open(path: &str) -> Result<Self> {
        Self::initialize(Connection::open(path)?)
    }

    fn initialize(connection: Connection) -> Result<Self> {
        connection.execute_batch(
            "CREATE TABLE IF NOT EXISTS matches (
                id INTEGER PRIMARY KEY,
                score INTEGER NOT NULL CHECK (score >= 0),
                outcome TEXT NOT NULL CHECK (outcome IN ('lost', 'won')),
                finished_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );",
        )?;
        Ok(Self { connection })
    }

    pub fn record_completed(&self, score: i32, won: bool) -> Result<()> {
        let outcome = if won { "won" } else { "lost" };
        self.connection.execute(
            "INSERT INTO matches (score, outcome) VALUES (?1, ?2)",
            params![score, outcome],
        )?;
        Ok(())
    }

    pub fn count_matches(&self) -> Result<i64> {
        self.connection
            .query_row("SELECT COUNT(*) FROM matches", [], |row| row.get(0))
    }

    /// Highest scores first; insertion order resolves score ties consistently.
    /// The SQL LIMIT prevents loading the full history into the game UI.
    pub fn top_ten_scores(&self) -> Result<Vec<i64>> {
        let mut statement = self
            .connection
            .prepare("SELECT score FROM matches ORDER BY score DESC, id ASC LIMIT 10")?;
        let scores = statement.query_map([], |row| row.get::<_, i64>(0))?;
        scores.collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn memory_store() -> ScoreStore {
        ScoreStore::initialize(Connection::open_in_memory().unwrap()).unwrap()
    }

    #[test]
    fn fresh_database_is_empty() {
        assert_eq!(memory_store().count_matches().unwrap(), 0);
    }

    #[test]
    fn stores_multiple_matches_and_outcomes() {
        let store = memory_store();
        store.record_completed(3, false).unwrap();
        store.record_completed(7, true).unwrap();
        assert_eq!(store.count_matches().unwrap(), 2);
        let outcome: String = store
            .connection
            .query_row("SELECT outcome FROM matches WHERE score = ?1", [7], |row| {
                row.get(0)
            })
            .unwrap();
        assert_eq!(outcome, "won");
    }

    #[test]
    fn rejects_negative_scores_without_inserting() {
        let store = memory_store();
        assert!(store.record_completed(-1, false).is_err());
        assert_eq!(store.count_matches().unwrap(), 0);
    }

    #[test]
    fn reopens_the_same_disk_database_with_history_intact() {
        use std::time::{SystemTime, UNIX_EPOCH};
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "renda-snake-ch10-{}-{nonce}.db",
            std::process::id()
        ));
        let name = path.to_str().unwrap();
        {
            let store = ScoreStore::open(name).unwrap();
            store.record_completed(9, true).unwrap();
        }
        {
            let reopened = ScoreStore::open(name).unwrap();
            assert_eq!(reopened.count_matches().unwrap(), 1);
        }
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn ranking_is_empty_before_first_completed_match() {
        let store = memory_store();
        assert!(store.top_ten_scores().unwrap().is_empty());
    }

    #[test]
    fn ranking_sorts_descending_and_limits_to_ten() {
        let store = memory_store();
        for score in [2, 9, 1, 5, 9, 3, 10, 7, 8, 4, 6, 0] {
            store.record_completed(score, false).unwrap();
        }
        assert_eq!(
            store.top_ten_scores().unwrap(),
            vec![10, 9, 9, 8, 7, 6, 5, 4, 3, 2]
        );
        assert_eq!(store.count_matches().unwrap(), 12);
    }

    #[test]
    fn ranking_is_read_only() {
        let store = memory_store();
        store.record_completed(6, true).unwrap();
        assert_eq!(store.top_ten_scores().unwrap(), vec![6]);
        assert_eq!(store.top_ten_scores().unwrap(), vec![6]);
        assert_eq!(store.count_matches().unwrap(), 1);
    }

    #[test]
    fn invalid_parent_directory_is_reported() {
        let path = std::env::temp_dir()
            .join(format!("renda-snake-ch10-missing-{}", std::process::id()))
            .join("history.db");
        assert!(ScoreStore::open(path.to_str().unwrap()).is_err());
    }
}

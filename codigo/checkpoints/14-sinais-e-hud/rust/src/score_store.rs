//! SQLite persistence is infrastructure, not part of the movement rules.
//! Open connections for history operations, never for game ticks.

use rusqlite::{params, Connection, Error, Result, TransactionBehavior};

const SCHEMA_VERSION: i64 = 2;

pub struct ScoreStore {
    connection: Connection,
}

impl ScoreStore {
    pub fn open(path: &str) -> Result<Self> {
        Self::initialize(Connection::open(path)?)
    }

    fn initialize(mut connection: Connection) -> Result<Self> {
        // Previous checkpoints created the table without setting user_version.
        let version: i64 = connection.pragma_query_value(None, "user_version", |row| row.get(0))?;
        if !(0..=SCHEMA_VERSION).contains(&version) {
            // Do not attempt to rewrite a database from a newer application.
            return Err(Error::InvalidQuery);
        }
        if version < SCHEMA_VERSION {
            let transaction =
                connection.transaction_with_behavior(TransactionBehavior::Immediate)?;
            if version == 0 {
                transaction.execute_batch(
                    "CREATE TABLE IF NOT EXISTS matches (
                        id INTEGER PRIMARY KEY,
                        score INTEGER NOT NULL CHECK (score >= 0),
                        outcome TEXT NOT NULL CHECK (outcome IN ('lost', 'won')),
                        finished_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                    );
                    PRAGMA user_version = 1;",
                )?;
            }
            if version <= 1 {
                // Existing rows receive a sentinel zero; future matches record real tick counts.
                transaction.execute_batch(
                    "ALTER TABLE matches
                        ADD COLUMN duration_ticks INTEGER NOT NULL DEFAULT 0
                        CHECK (duration_ticks >= 0);
                    CREATE INDEX IF NOT EXISTS idx_matches_ranking
                        ON matches (score DESC, id ASC);
                    PRAGMA user_version = 2;",
                )?;
            }
            // All schema updates and version changes succeed or roll back together.
            transaction.commit()?;
        }
        let health: String =
            connection.pragma_query_value(None, "quick_check", |row| row.get(0))?;
        if health != "ok" {
            return Err(Error::InvalidQuery);
        }
        Ok(Self { connection })
    }

    pub fn schema_version(&self) -> Result<i64> {
        self.connection
            .pragma_query_value(None, "user_version", |row| row.get(0))
    }

    pub fn record_completed(&self, score: i32, won: bool, duration_ticks: i32) -> Result<()> {
        let outcome = if won { "won" } else { "lost" };
        self.connection.execute(
            "INSERT INTO matches (score, outcome, duration_ticks) VALUES (?1, ?2, ?3)",
            params![score, outcome, duration_ticks],
        )?;
        Ok(())
    }

    /// A consistent SQLite snapshot at a NEW path, not a raw copy of an active DB.
    /// VACUUM INTO requires a destination that does not already contain a database.
    pub fn backup_to(&self, destination_path: &str) -> Result<()> {
        self.connection
            .execute("VACUUM INTO ?1", [destination_path])?;
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
        store.record_completed(3, false, 0).unwrap();
        store.record_completed(7, true, 0).unwrap();
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
        assert!(store.record_completed(-1, false, 0).is_err());
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
            "renda-snake-ch12-{}-{nonce}.db",
            std::process::id()
        ));
        let name = path.to_str().unwrap();
        {
            let store = ScoreStore::open(name).unwrap();
            store.record_completed(9, true, 0).unwrap();
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
            store.record_completed(score, false, 0).unwrap();
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
        store.record_completed(6, true, 0).unwrap();
        assert_eq!(store.top_ten_scores().unwrap(), vec![6]);
        assert_eq!(store.top_ten_scores().unwrap(), vec![6]);
        assert_eq!(store.count_matches().unwrap(), 1);
    }

    #[test]
    fn new_database_has_version_two_and_tick_count() {
        let store = memory_store();
        assert_eq!(store.schema_version().unwrap(), 2);
        store.record_completed(4, true, 18).unwrap();
        let ticks: i64 = store
            .connection
            .query_row("SELECT duration_ticks FROM matches", [], |row| row.get(0))
            .unwrap();
        assert_eq!(ticks, 18);
    }

    #[test]
    fn legacy_database_migrates_and_preserves_history() {
        let connection = Connection::open_in_memory().unwrap();
        connection
            .execute_batch(
                "CREATE TABLE matches (
                id INTEGER PRIMARY KEY,
                score INTEGER NOT NULL CHECK (score >= 0),
                outcome TEXT NOT NULL CHECK (outcome IN ('lost', 'won')),
                finished_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
            INSERT INTO matches (score, outcome) VALUES (19, 'won');",
            )
            .unwrap();
        let store = ScoreStore::initialize(connection).unwrap();
        assert_eq!(store.schema_version().unwrap(), 2);
        assert_eq!(store.top_ten_scores().unwrap(), vec![19]);
        let ticks: i64 = store
            .connection
            .query_row("SELECT duration_ticks FROM matches", [], |row| row.get(0))
            .unwrap();
        assert_eq!(ticks, 0);
    }

    #[test]
    fn migration_is_idempotent_on_reopen() {
        let store = memory_store();
        store.record_completed(6, false, 5).unwrap();
        let connection = store.connection;
        let reopened = ScoreStore::initialize(connection).unwrap();
        assert_eq!(reopened.count_matches().unwrap(), 1);
        assert_eq!(reopened.schema_version().unwrap(), 2);
    }

    #[test]
    fn newer_version_is_rejected_without_overwriting_rows() {
        use std::time::{SystemTime, UNIX_EPOCH};

        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "renda-snake-newer-schema-{}-{nonce}.db",
            std::process::id()
        ));

        {
            let connection = Connection::open(&path).unwrap();
            connection
                .execute_batch(
                    "CREATE TABLE matches (id INTEGER PRIMARY KEY, score INTEGER);
                     INSERT INTO matches (score) VALUES (17);
                     PRAGMA user_version = 99;",
                )
                .unwrap();
        }

        assert!(ScoreStore::open(path.to_str().unwrap()).is_err());

        // Reopen independently: a rejected schema must not be rewritten.
        let connection = Connection::open(&path).unwrap();
        let version: i64 = connection
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap();
        let score: i64 = connection
            .query_row("SELECT score FROM matches", [], |row| row.get(0))
            .unwrap();
        assert_eq!(version, 99);
        assert_eq!(score, 17);
        drop(connection);
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn failed_legacy_migration_rolls_back_column_and_version() {
        use std::time::{SystemTime, UNIX_EPOCH};

        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "renda-snake-incompatible-schema-{}-{nonce}.db",
            std::process::id()
        ));

        {
            let connection = Connection::open(&path).unwrap();
            connection
                .execute_batch(
                    "CREATE TABLE matches (id INTEGER PRIMARY KEY, legacy_points INTEGER);
                     INSERT INTO matches (legacy_points) VALUES (13);",
                )
                .unwrap();
        }

        // ALTER adds duration_ticks, then the index creation fails (no score).
        // The entire transaction must roll back instead of recording v2.
        assert!(ScoreStore::open(path.to_str().unwrap()).is_err());

        let connection = Connection::open(&path).unwrap();
        let version: i64 = connection
            .pragma_query_value(None, "user_version", |row| row.get(0))
            .unwrap();
        let columns_added: i64 = connection
            .query_row(
                "SELECT COUNT(*) FROM pragma_table_info('matches')
                 WHERE name = 'duration_ticks'",
                [],
                |row| row.get(0),
            )
            .unwrap();
        let previous_row: i64 = connection
            .query_row("SELECT legacy_points FROM matches", [], |row| row.get(0))
            .unwrap();
        assert_eq!(version, 0);
        assert_eq!(columns_added, 0);
        assert_eq!(previous_row, 13);
        drop(connection);
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn database_rejects_negative_duration() {
        let store = memory_store();
        assert!(store.record_completed(5, false, -1).is_err());
        assert_eq!(store.count_matches().unwrap(), 0);
    }

    #[test]
    fn backup_is_consistent_and_preserves_rows() {
        use std::time::{SystemTime, UNIX_EPOCH};
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "renda-snake-ch12-backup-{}-{nonce}.db",
            std::process::id()
        ));
        let destination = path.to_str().unwrap();
        let store = memory_store();
        store.record_completed(23, true, 90).unwrap();
        store.backup_to(destination).unwrap();
        let restored = ScoreStore::open(destination).unwrap();
        assert_eq!(restored.schema_version().unwrap(), 2);
        assert_eq!(restored.top_ten_scores().unwrap(), vec![23]);
        drop(restored);
        std::fs::remove_file(path).unwrap();
    }

    #[test]
    fn invalid_parent_directory_is_reported() {
        let path = std::env::temp_dir()
            .join(format!("renda-snake-ch12-missing-{}", std::process::id()))
            .join("history.db");
        assert!(ScoreStore::open(path.to_str().unwrap()).is_err());
    }
}

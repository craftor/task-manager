use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, FixedOffset};

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct JournalEntry {
    pub id: String,
    pub user_id: String,
    pub date_key: String,
    pub content: String,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: DateTime<FixedOffset>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateJournalEntry {
    pub date_key: String,
    pub content: String,
}
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, FixedOffset};

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct SpecialDay {
    pub id: String,
    pub user_id: String,
    pub date_key: String,
    pub data: String,
    pub updated_at: DateTime<FixedOffset>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertSpecialDay {
    pub date_key: String,
    pub data: serde_json::Value,
}
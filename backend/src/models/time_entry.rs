use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, FixedOffset};

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct TimeEntry {
    pub id: String,
    pub user_id: String,
    pub task_id: String,
    pub start_time: DateTime<FixedOffset>,
    pub end_time: Option<DateTime<FixedOffset>>,
    pub duration_minutes: Option<i32>,
    pub note: String,
    pub manual: bool,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: DateTime<FixedOffset>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTimeEntry {
    pub task_id: String,
    pub start_time: DateTime<FixedOffset>,
    pub end_time: Option<DateTime<FixedOffset>>,
    pub duration_minutes: Option<i32>,
    #[serde(default)]
    pub note: String,
    #[serde(default)]
    pub manual: bool,
}
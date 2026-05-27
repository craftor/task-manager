use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use chrono::{DateTime, Utc, FixedOffset};

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Task {
    pub id: String,
    pub user_id: String,
    pub project_id: String,
    pub parent_task_id: Option<String>,
    pub title: String,
    pub description: String,
    pub priority: i32,
    pub status: i32,
    pub start_date: Option<DateTime<FixedOffset>>,
    pub due_date: Option<DateTime<FixedOffset>>,
    pub tags: String,
    pub estimated_minutes: Option<i32>,
    pub actual_minutes: Option<i32>,
    pub is_recurring: bool,
    pub recurring_rule: Option<String>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: DateTime<FixedOffset>,
    pub sort_order: i32,
    pub deleted_at: Option<DateTime<FixedOffset>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTask {
    pub project_id: String,
    pub parent_task_id: Option<String>,
    pub title: String,
    #[serde(default = "default_desc")]
    pub description: String,
    #[serde(default = "default_priority")]
    pub priority: i32,
    #[serde(default)]
    pub status: i32,
    pub start_date: Option<DateTime<FixedOffset>>,
    pub due_date: Option<DateTime<FixedOffset>>,
    #[serde(default = "default_tags")]
    pub tags: String,
    pub estimated_minutes: Option<i32>,
    pub actual_minutes: Option<i32>,
    #[serde(default)]
    pub is_recurring: bool,
    pub recurring_rule: Option<String>,
    #[serde(default)]
    pub sort_order: i32,
}

fn default_desc() -> String {
    "".to_string()
}

fn default_priority() -> i32 {
    2
}

fn default_tags() -> String {
    "[]".to_string()
}
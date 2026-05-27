use axum::{
    extract::{Extension, Path, Query, State},
    response::Json,
    http::StatusCode,
};
use std::sync::Arc;
use serde::Deserialize;
use crate::db;
use crate::models;
use crate::error::AppError;
use crate::middleware::auth::AuthenticatedUser;
use crate::db::DbPool;

#[derive(Debug, Deserialize)]
pub struct TimeEntryFilter {
    pub task_id: Option<String>,
}

pub async fn list(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Query(filter): Query<TimeEntryFilter>,
) -> Result<Json<Vec<models::TimeEntry>>, AppError> {
    let entries = db::list_time_entries(pool.as_ref(), &user.0, filter.task_id.as_deref()).await?;
    Ok(Json(entries))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<Json<models::TimeEntry>, AppError> {
    let entry = db::get_time_entry(pool.as_ref(), &id, &user.0).await?;
    Ok(Json(entry))
}

pub async fn create(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::CreateTimeEntry>,
) -> Result<(StatusCode, Json<models::TimeEntry>), AppError> {
    let entry = db::create_time_entry(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(entry)))
}

pub async fn update(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
    Json(payload): Json<models::CreateTimeEntry>,
) -> Result<Json<models::TimeEntry>, AppError> {
    let entry = db::update_time_entry(pool.as_ref(), &id, &user.0, &payload).await?;
    Ok(Json(entry))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_time_entry(pool.as_ref(), &id, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
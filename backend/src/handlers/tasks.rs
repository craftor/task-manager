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
pub struct TaskFilter {
    pub project_id: Option<String>,
}

pub async fn list(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Query(filter): Query<TaskFilter>,
) -> Result<Json<Vec<models::Task>>, AppError> {
    let tasks = db::list_tasks(pool.as_ref(), &user.0, filter.project_id.as_deref()).await?;
    Ok(Json(tasks))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<Json<models::Task>, AppError> {
    let task = db::get_task(pool.as_ref(), &id, &user.0).await?;
    Ok(Json(task))
}

pub async fn create(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::CreateTask>,
) -> Result<(StatusCode, Json<models::Task>), AppError> {
    let task = db::create_task(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(task)))
}

pub async fn update(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
    Json(payload): Json<models::CreateTask>,
) -> Result<Json<models::Task>, AppError> {
    let task = db::update_task(pool.as_ref(), &id, &user.0, &payload).await?;
    Ok(Json(task))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_task(pool.as_ref(), &id, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
use axum::{
    extract::{Extension, Path, State},
    response::Json,
    http::StatusCode,
};
use std::sync::Arc;
use crate::db;
use crate::models;
use crate::error::AppError;
use crate::middleware::auth::AuthenticatedUser;
use crate::db::DbPool;

pub async fn list(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
) -> Result<Json<Vec<models::JournalEntry>>, AppError> {
    let entries = db::list_journal_entries(pool.as_ref(), &user.0).await?;
    Ok(Json(entries))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<Json<models::JournalEntry>, AppError> {
    let entry = db::get_journal_entry(pool.as_ref(), &id, &user.0).await?;
    Ok(Json(entry))
}

pub async fn create(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::CreateJournalEntry>,
) -> Result<(StatusCode, Json<models::JournalEntry>), AppError> {
    let entry = db::create_journal_entry(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(entry)))
}

pub async fn update(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
    Json(payload): Json<models::CreateJournalEntry>,
) -> Result<Json<models::JournalEntry>, AppError> {
    let entry = db::update_journal_entry(pool.as_ref(), &id, &user.0, &payload).await?;
    Ok(Json(entry))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_journal_entry(pool.as_ref(), &id, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
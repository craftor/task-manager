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
) -> Result<Json<Vec<models::Mood>>, AppError> {
    let moods = db::list_moods(pool.as_ref(), &user.0).await?;
    Ok(Json(moods))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(date_key): Path<String>,
) -> Result<Json<models::Mood>, AppError> {
    let mood = db::get_mood(pool.as_ref(), &date_key, &user.0).await?;
    Ok(Json(mood))
}

pub async fn upsert(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::UpsertMood>,
) -> Result<(StatusCode, Json<models::Mood>), AppError> {
    let mood = db::upsert_mood(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(mood)))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(date_key): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_mood(pool.as_ref(), &date_key, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
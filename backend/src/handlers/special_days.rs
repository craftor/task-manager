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
) -> Result<Json<Vec<models::SpecialDay>>, AppError> {
    let days = db::list_special_days(pool.as_ref(), &user.0).await?;
    Ok(Json(days))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(date_key): Path<String>,
) -> Result<Json<models::SpecialDay>, AppError> {
    let day = db::get_special_day(pool.as_ref(), &date_key, &user.0).await?;
    Ok(Json(day))
}

pub async fn upsert(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::UpsertSpecialDay>,
) -> Result<(StatusCode, Json<models::SpecialDay>), AppError> {
    let day = db::upsert_special_day(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(day)))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(date_key): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_special_day(pool.as_ref(), &date_key, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
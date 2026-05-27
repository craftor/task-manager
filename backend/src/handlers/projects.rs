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
) -> Result<Json<Vec<models::Project>>, AppError> {
    let projects = db::list_projects(pool.as_ref(), &user.0).await?;
    Ok(Json(projects))
}

pub async fn get(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<Json<models::Project>, AppError> {
    let project = db::get_project(pool.as_ref(), &id, &user.0).await?;
    Ok(Json(project))
}

pub async fn create(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Json(payload): Json<models::CreateProject>,
) -> Result<(StatusCode, Json<models::Project>), AppError> {
    let project = db::create_project(pool.as_ref(), &payload, &user.0).await?;
    Ok((StatusCode::CREATED, Json(project)))
}

pub async fn update(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
    Json(payload): Json<models::CreateProject>,
) -> Result<Json<models::Project>, AppError> {
    let project = db::update_project(pool.as_ref(), &id, &user.0, &payload).await?;
    Ok(Json(project))
}

pub async fn delete(
    Extension(user): Extension<AuthenticatedUser>,
    State(pool): State<Arc<DbPool>>,
    Path(id): Path<String>,
) -> Result<StatusCode, AppError> {
    db::delete_project(pool.as_ref(), &id, &user.0).await?;
    Ok(StatusCode::NO_CONTENT)
}
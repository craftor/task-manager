use axum::{
    response::{IntoResponse, Json},
    http::StatusCode,
};
use serde_json::json;
use thiserror::Error;
use sqlx::Error as SqlxError;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("Unauthorized")]
    Unauthorized,
    #[error("Not found: {0}")]
    NotFound(String),
    #[error("Bad request: {0}")]
    BadRequest(String),
    #[error("Database error")]
    SqlxError(#[from] SqlxError),
    #[error("Internal error: {0}")]
    Internal(String),
}

impl IntoResponse for AppError {
    fn into_response(self) -> axum::response::Response {
        let (status, error_type, message) = match &self {
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "Unauthorized", self.to_string()),
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, "NotFound", msg.clone()),
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "BadRequest", msg.clone()),
            AppError::SqlxError(e) => {
                tracing::error!("Database error: {:?}", e);
                (StatusCode::INTERNAL_SERVER_ERROR, "Internal", "Database error".to_string())
            }
            AppError::Internal(msg) => (StatusCode::INTERNAL_SERVER_ERROR, "Internal", msg.clone()),
        };
        let body = Json(json!({
            "error": error_type,
            "message": message
        }));
        (status, body).into_response()
    }
}
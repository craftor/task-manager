use axum::{
    body::Body,
    extract::State,
    http::Request,
    middleware::Next,
    response::Response,
};
use std::sync::Arc;
use crate::db::DbPool;

#[derive(Clone)]
pub struct AuthenticatedUser(pub String);

pub async fn auth_middleware(
    State(_pool): State<Arc<DbPool>>,
    mut request: Request<Body>,
    next: Next,
) -> Response {
    let user_id = request
        .headers()
        .get("x-user-id")
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());

    match user_id {
        Some(uid) => {
            request.extensions_mut().insert(AuthenticatedUser(uid));
            next.run(request).await
        }
        None => {
            let body = serde_json::json!({
                "error": "Unauthorized",
                "message": "Missing x-user-id header"
            });
            let response = axum::http::Response::builder()
                .status(axum::http::StatusCode::UNAUTHORIZED)
                .header("Content-Type", "application/json")
                .body(axum::body::Body::from(body.to_string()))
                .unwrap();
            response
        }
    }
}
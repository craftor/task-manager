use axum::{
    Router,
    routing::{get, post, put, delete},
};
use std::sync::Arc;
use crate::db::DbPool;
use crate::handlers;
use crate::middleware::auth::auth_middleware;

pub fn create_router(pool: Arc<DbPool>) -> Router {
    let api = Router::new()
        // Projects
        .route("/projects", get(handlers::projects::list))
        .route("/projects", post(handlers::projects::create))
        .route("/projects/:id", get(handlers::projects::get))
        .route("/projects/:id", put(handlers::projects::update))
        .route("/projects/:id", delete(handlers::projects::delete))
        // Tasks
        .route("/tasks", get(handlers::tasks::list))
        .route("/tasks", post(handlers::tasks::create))
        .route("/tasks/:id", get(handlers::tasks::get))
        .route("/tasks/:id", put(handlers::tasks::update))
        .route("/tasks/:id", delete(handlers::tasks::delete))
        // TimeEntries
        .route("/time-entries", get(handlers::time_entries::list))
        .route("/time-entries", post(handlers::time_entries::create))
        .route("/time-entries/:id", get(handlers::time_entries::get))
        .route("/time-entries/:id", put(handlers::time_entries::update))
        .route("/time-entries/:id", delete(handlers::time_entries::delete))
        // SpecialDays
        .route("/special-days", get(handlers::special_days::list))
        .route("/special-days", post(handlers::special_days::upsert))
        .route("/special-days/:date_key", get(handlers::special_days::get))
        .route("/special-days/:date_key", delete(handlers::special_days::delete))
        // Moods
        .route("/moods", get(handlers::moods::list))
        .route("/moods", post(handlers::moods::upsert))
        .route("/moods/:date_key", get(handlers::moods::get))
        .route("/moods/:date_key", delete(handlers::moods::delete))
        // JournalEntries
        .route("/journal-entries", get(handlers::journal_entries::list))
        .route("/journal-entries", post(handlers::journal_entries::create))
        .route("/journal-entries/:id", get(handlers::journal_entries::get))
        .route("/journal-entries/:id", put(handlers::journal_entries::update))
        .route("/journal-entries/:id", delete(handlers::journal_entries::delete))
        .layer(axum::middleware::from_fn_with_state(pool.clone(), auth_middleware));

    Router::new()
        .nest("/api", api)
        .with_state(pool)
}
mod config;
mod error;
mod db;
mod models;
mod middleware;
mod handlers;
mod routes;

use std::sync::Arc;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use config::Config;
use db::create_pool;
use routes::create_router;

#[tokio::main]
async fn main() {
    // Initialize logging
    let rust_log = std::env::var("RUST_LOG").unwrap_or_else(|_| "info".to_string());
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(&rust_log))
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load config - dotenv errors are non-fatal since env vars are set by docker-compose
    let config = match Config::from_env() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("CONFIG ERROR: {:?}", e);
            eprintln!("DATABASE_URL = {:?}", std::env::var("DATABASE_URL").ok());
            eprintln!("SERVER_HOST = {:?}", std::env::var("SERVER_HOST").ok());
            eprintln!("SERVER_PORT = {:?}", std::env::var("SERVER_PORT").ok());
            eprintln!("RUST_LOG = {:?}", std::env::var("RUST_LOG").ok());
            std::process::exit(1);
        }
    };

    tracing::info!("Starting server on {}:{}", config.server_host, config.server_port);
    tracing::info!("Database URL host: {}", config.database_url.split('@').nth(1).unwrap_or("unknown"));

    let pool = match create_pool(&config.database_url).await {
        Ok(p) => {
            tracing::info!("Database connection established");
            Arc::new(p)
        }
        Err(e) => {
            eprintln!("DATABASE CONNECTION ERROR: {:?}", e);
            std::process::exit(1);
        }
    };

    let app = create_router(pool);
    let listener = tokio::net::TcpListener::bind(format!("{}:{}", config.server_host, config.server_port)).await
        .expect("Failed to bind TCP listener");
    tracing::info!("Listening on {}", listener.local_addr().expect("Failed to get local addr"));
    axum::serve(listener, app).await.expect("Server failed");
}
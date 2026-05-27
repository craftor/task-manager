use std::env;
use dotenvy::dotenv;

#[derive(Clone)]
pub struct Config {
    pub database_url: String,
    pub server_host: String,
    pub server_port: u16,
}

impl Config {
    pub fn from_env() -> Result<Self, dotenvy::Error> {
        // Try to load .env from /app first (Docker mount), fall back to current dir
        let _ = dotenv().or_else(|_| {
            let _ = std::env::set_current_dir("/app");
            dotenv()
        });

        Ok(Self {
            database_url: env::var("DATABASE_URL").expect("DATABASE_URL must be set"),
            server_host: env::var("SERVER_HOST").unwrap_or_else(|_| "0.0.0.0".to_string()),
            server_port: env::var("SERVER_PORT")
                .unwrap_or_else(|_| "8080".to_string())
                .parse()
                .expect("SERVER_PORT must be a valid port number"),
        })
    }
}
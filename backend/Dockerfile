# Build stage
FROM rust:1.88-slim AS build
WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
RUN mkdir -p src && echo "fn main() {}" > src/main.rs
RUN cargo build --release && rm -rf src
COPY src ./src
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libpq5 curl && rm -rf /var/lib/apt/lists/*
RUN useradd -m appuser
COPY --from=build /app/target/release/task-manager-backend /usr/local/bin/
WORKDIR /app
USER appuser
CMD ["sh", "-c", "/usr/local/bin/task-manager-backend; sleep infinity"]
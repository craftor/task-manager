CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE projects (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    parent_id TEXT,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT NOT NULL DEFAULT '#6366f1',
    icon TEXT NOT NULL DEFAULT 'folder',
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ
);
CREATE INDEX projects_user_id_idx ON projects(user_id) WHERE deleted_at IS NULL;

CREATE TABLE tasks (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    parent_task_id TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    priority INTEGER NOT NULL DEFAULT 2,
    status INTEGER NOT NULL DEFAULT 0,
    start_date TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    tags TEXT NOT NULL DEFAULT '[]',
    estimated_minutes INTEGER,
    actual_minutes INTEGER,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    recurring_rule TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sort_order INTEGER NOT NULL DEFAULT 0,
    deleted_at TIMESTAMPTZ
);
CREATE INDEX tasks_user_id_idx ON tasks(user_id) WHERE deleted_at IS NULL;
CREATE INDEX tasks_project_id_idx ON tasks(project_id) WHERE deleted_at IS NULL;

CREATE TABLE time_entries (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    duration_minutes INTEGER,
    note TEXT NOT NULL DEFAULT '',
    manual BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX time_entries_user_id_idx ON time_entries(user_id);
CREATE INDEX time_entries_task_id_idx ON time_entries(task_id);

CREATE TABLE special_days (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date_key TEXT NOT NULL,
    data TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX special_days_user_date_idx ON special_days(user_id, date_key);

CREATE TABLE moods (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    date_key TEXT NOT NULL,
    data TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX moods_user_date_idx ON moods(user_id, date_key);

CREATE TABLE journal_entries (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    user_id TEXT NOT NULL,
    date_key TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX journal_entries_user_id_idx ON journal_entries(user_id);
CREATE UNIQUE INDEX journal_entries_user_date_idx ON journal_entries(user_id, date_key);
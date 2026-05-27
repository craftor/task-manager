use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;
use sqlx::Row;
use crate::error::AppError;

pub type DbPool = PgPool;

pub async fn create_pool(database_url: &str) -> Result<DbPool, AppError> {
    PgPoolOptions::new()
        .max_connections(10)
        .connect(database_url)
        .await
        .map_err(AppError::from)
}

// Projects
pub async fn list_projects(pool: &DbPool, user_id: &str) -> Result<Vec<super::models::Project>, AppError> {
    let rows = sqlx::query(
        r#"SELECT id, user_id, parent_id, name, description, color, icon,
            start_date, end_date, created_at, updated_at, sort_order,
            is_default, deleted_at
         FROM projects
         WHERE user_id = $1 AND deleted_at IS NULL
         ORDER BY sort_order"#
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    rows.iter().map(|row| {
        Ok(super::models::Project {
            id: row.get("id"),
            user_id: row.get("user_id"),
            parent_id: row.get("parent_id"),
            name: row.get("name"),
            description: row.get("description"),
            color: row.get("color"),
            icon: row.get("icon"),
            start_date: row.get("start_date"),
            end_date: row.get("end_date"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
            sort_order: row.get("sort_order"),
            is_default: row.get("is_default"),
            deleted_at: row.get("deleted_at"),
        })
    }).collect()
}

pub async fn get_project(pool: &DbPool, id: &str, user_id: &str) -> Result<super::models::Project, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, parent_id, name, description, color, icon,
            start_date, end_date, created_at, updated_at, sort_order,
            is_default, deleted_at
         FROM projects
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"#
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Project not found".to_string()))?;

    Ok(super::models::Project {
        id: row.get("id"),
        user_id: row.get("user_id"),
        parent_id: row.get("parent_id"),
        name: row.get("name"),
        description: row.get("description"),
        color: row.get("color"),
        icon: row.get("icon"),
        start_date: row.get("start_date"),
        end_date: row.get("end_date"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        is_default: row.get("is_default"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn create_project(pool: &DbPool, project: &super::models::CreateProject, user_id: &str) -> Result<super::models::Project, AppError> {
    let row = sqlx::query(
        r#"INSERT INTO projects (user_id, parent_id, name, description, color, icon,
            start_date, end_date, sort_order, is_default)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING id, user_id, parent_id, name, description, color, icon,
            start_date, end_date, created_at, updated_at, sort_order,
            is_default, deleted_at"#
    )
    .bind(user_id)
    .bind(&project.parent_id)
    .bind(&project.name)
    .bind(&project.description)
    .bind(&project.color)
    .bind(&project.icon)
    .bind(&project.start_date)
    .bind(&project.end_date)
    .bind(project.sort_order)
    .bind(project.is_default)
    .fetch_one(pool)
    .await?;

    Ok(super::models::Project {
        id: row.get("id"),
        user_id: row.get("user_id"),
        parent_id: row.get("parent_id"),
        name: row.get("name"),
        description: row.get("description"),
        color: row.get("color"),
        icon: row.get("icon"),
        start_date: row.get("start_date"),
        end_date: row.get("end_date"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        is_default: row.get("is_default"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn update_project(pool: &DbPool, id: &str, user_id: &str, project: &super::models::CreateProject) -> Result<super::models::Project, AppError> {
    let row = sqlx::query(
        r#"UPDATE projects
         SET parent_id = $3, name = $4, description = $5, color = $6, icon = $7,
             start_date = $8, end_date = $9, sort_order = $10, is_default = $11,
             updated_at = NOW()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
         RETURNING id, user_id, parent_id, name, description, color, icon,
            start_date, end_date, created_at, updated_at, sort_order,
            is_default, deleted_at"#
    )
    .bind(id)
    .bind(user_id)
    .bind(&project.parent_id)
    .bind(&project.name)
    .bind(&project.description)
    .bind(&project.color)
    .bind(&project.icon)
    .bind(&project.start_date)
    .bind(&project.end_date)
    .bind(project.sort_order)
    .bind(project.is_default)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Project not found".to_string()))?;

    Ok(super::models::Project {
        id: row.get("id"),
        user_id: row.get("user_id"),
        parent_id: row.get("parent_id"),
        name: row.get("name"),
        description: row.get("description"),
        color: row.get("color"),
        icon: row.get("icon"),
        start_date: row.get("start_date"),
        end_date: row.get("end_date"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        is_default: row.get("is_default"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn delete_project(pool: &DbPool, id: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"UPDATE projects SET deleted_at = NOW(), updated_at = NOW()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"#
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Project not found".to_string()));
    }
    Ok(())
}

// Tasks
pub async fn list_tasks(pool: &DbPool, user_id: &str, project_id: Option<&str>) -> Result<Vec<super::models::Task>, AppError> {
    let rows = match project_id {
        Some(pid) => {
            sqlx::query(
                r#"SELECT id, user_id, project_id, parent_task_id, title, description,
                    priority, status, start_date, due_date, tags, estimated_minutes,
                    actual_minutes, is_recurring, recurring_rule, created_at, updated_at,
                    sort_order, deleted_at
                 FROM tasks
                 WHERE user_id = $1 AND project_id = $2 AND deleted_at IS NULL
                 ORDER BY sort_order"#
            )
            .bind(user_id)
            .bind(pid)
            .fetch_all(pool)
            .await?
        }
        None => {
            sqlx::query(
                r#"SELECT id, user_id, project_id, parent_task_id, title, description,
                    priority, status, start_date, due_date, tags, estimated_minutes,
                    actual_minutes, is_recurring, recurring_rule, created_at, updated_at,
                    sort_order, deleted_at
                 FROM tasks
                 WHERE user_id = $1 AND deleted_at IS NULL
                 ORDER BY sort_order"#
            )
            .bind(user_id)
            .fetch_all(pool)
            .await?
        }
    };

    rows.iter().map(|row| {
        Ok(super::models::Task {
            id: row.get("id"),
            user_id: row.get("user_id"),
            project_id: row.get("project_id"),
            parent_task_id: row.get("parent_task_id"),
            title: row.get("title"),
            description: row.get("description"),
            priority: row.get("priority"),
            status: row.get("status"),
            start_date: row.get("start_date"),
            due_date: row.get("due_date"),
            tags: row.get("tags"),
            estimated_minutes: row.get("estimated_minutes"),
            actual_minutes: row.get("actual_minutes"),
            is_recurring: row.get("is_recurring"),
            recurring_rule: row.get("recurring_rule"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
            sort_order: row.get("sort_order"),
            deleted_at: row.get("deleted_at"),
        })
    }).collect()
}

pub async fn get_task(pool: &DbPool, id: &str, user_id: &str) -> Result<super::models::Task, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, project_id, parent_task_id, title, description,
            priority, status, start_date, due_date, tags, estimated_minutes,
            actual_minutes, is_recurring, recurring_rule, created_at, updated_at,
            sort_order, deleted_at
         FROM tasks
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"#
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Task not found".to_string()))?;

    Ok(super::models::Task {
        id: row.get("id"),
        user_id: row.get("user_id"),
        project_id: row.get("project_id"),
        parent_task_id: row.get("parent_task_id"),
        title: row.get("title"),
        description: row.get("description"),
        priority: row.get("priority"),
        status: row.get("status"),
        start_date: row.get("start_date"),
        due_date: row.get("due_date"),
        tags: row.get("tags"),
        estimated_minutes: row.get("estimated_minutes"),
        actual_minutes: row.get("actual_minutes"),
        is_recurring: row.get("is_recurring"),
        recurring_rule: row.get("recurring_rule"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn create_task(pool: &DbPool, task: &super::models::CreateTask, user_id: &str) -> Result<super::models::Task, AppError> {
    let row = sqlx::query(
        r#"INSERT INTO tasks (user_id, project_id, parent_task_id, title, description,
            priority, status, start_date, due_date, tags, estimated_minutes,
            actual_minutes, is_recurring, recurring_rule, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         RETURNING id, user_id, project_id, parent_task_id, title, description,
            priority, status, start_date, due_date, tags, estimated_minutes,
            actual_minutes, is_recurring, recurring_rule, created_at, updated_at,
            sort_order, deleted_at"#
    )
    .bind(user_id)
    .bind(&task.project_id)
    .bind(&task.parent_task_id)
    .bind(&task.title)
    .bind(&task.description)
    .bind(task.priority)
    .bind(task.status)
    .bind(&task.start_date)
    .bind(&task.due_date)
    .bind(&task.tags)
    .bind(task.estimated_minutes)
    .bind(task.actual_minutes)
    .bind(task.is_recurring)
    .bind(&task.recurring_rule)
    .bind(task.sort_order)
    .fetch_one(pool)
    .await?;

    Ok(super::models::Task {
        id: row.get("id"),
        user_id: row.get("user_id"),
        project_id: row.get("project_id"),
        parent_task_id: row.get("parent_task_id"),
        title: row.get("title"),
        description: row.get("description"),
        priority: row.get("priority"),
        status: row.get("status"),
        start_date: row.get("start_date"),
        due_date: row.get("due_date"),
        tags: row.get("tags"),
        estimated_minutes: row.get("estimated_minutes"),
        actual_minutes: row.get("actual_minutes"),
        is_recurring: row.get("is_recurring"),
        recurring_rule: row.get("recurring_rule"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn update_task(pool: &DbPool, id: &str, user_id: &str, task: &super::models::CreateTask) -> Result<super::models::Task, AppError> {
    let row = sqlx::query(
        r#"UPDATE tasks
         SET project_id = $3, parent_task_id = $4, title = $5, description = $6,
             priority = $7, status = $8, start_date = $9, due_date = $10, tags = $11,
             estimated_minutes = $12, actual_minutes = $13, is_recurring = $14,
             recurring_rule = $15, sort_order = $16, updated_at = NOW()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL
         RETURNING id, user_id, project_id, parent_task_id, title, description,
            priority, status, start_date, due_date, tags, estimated_minutes,
            actual_minutes, is_recurring, recurring_rule, created_at, updated_at,
            sort_order, deleted_at"#
    )
    .bind(id)
    .bind(user_id)
    .bind(&task.project_id)
    .bind(&task.parent_task_id)
    .bind(&task.title)
    .bind(&task.description)
    .bind(task.priority)
    .bind(task.status)
    .bind(&task.start_date)
    .bind(&task.due_date)
    .bind(&task.tags)
    .bind(task.estimated_minutes)
    .bind(task.actual_minutes)
    .bind(task.is_recurring)
    .bind(&task.recurring_rule)
    .bind(task.sort_order)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Task not found".to_string()))?;

    Ok(super::models::Task {
        id: row.get("id"),
        user_id: row.get("user_id"),
        project_id: row.get("project_id"),
        parent_task_id: row.get("parent_task_id"),
        title: row.get("title"),
        description: row.get("description"),
        priority: row.get("priority"),
        status: row.get("status"),
        start_date: row.get("start_date"),
        due_date: row.get("due_date"),
        tags: row.get("tags"),
        estimated_minutes: row.get("estimated_minutes"),
        actual_minutes: row.get("actual_minutes"),
        is_recurring: row.get("is_recurring"),
        recurring_rule: row.get("recurring_rule"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        sort_order: row.get("sort_order"),
        deleted_at: row.get("deleted_at"),
    })
}

pub async fn delete_task(pool: &DbPool, id: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"UPDATE tasks SET deleted_at = NOW(), updated_at = NOW()
         WHERE id = $1 AND user_id = $2 AND deleted_at IS NULL"#
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Task not found".to_string()));
    }
    Ok(())
}

// TimeEntries
pub async fn list_time_entries(pool: &DbPool, user_id: &str, task_id: Option<&str>) -> Result<Vec<super::models::TimeEntry>, AppError> {
    let rows = match task_id {
        Some(tid) => {
            sqlx::query(
                r#"SELECT id, user_id, task_id, start_time, end_time,
                    duration_minutes, note, manual, created_at, updated_at
                 FROM time_entries
                 WHERE user_id = $1 AND task_id = $2
                 ORDER BY start_time DESC"#
            )
            .bind(user_id)
            .bind(tid)
            .fetch_all(pool)
            .await?
        }
        None => {
            sqlx::query(
                r#"SELECT id, user_id, task_id, start_time, end_time,
                    duration_minutes, note, manual, created_at, updated_at
                 FROM time_entries
                 WHERE user_id = $1
                 ORDER BY start_time DESC"#
            )
            .bind(user_id)
            .fetch_all(pool)
            .await?
        }
    };

    rows.iter().map(|row| {
        Ok(super::models::TimeEntry {
            id: row.get("id"),
            user_id: row.get("user_id"),
            task_id: row.get("task_id"),
            start_time: row.get("start_time"),
            end_time: row.get("end_time"),
            duration_minutes: row.get("duration_minutes"),
            note: row.get("note"),
            manual: row.get("manual"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        })
    }).collect()
}

pub async fn get_time_entry(pool: &DbPool, id: &str, user_id: &str) -> Result<super::models::TimeEntry, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, task_id, start_time, end_time,
            duration_minutes, note, manual, created_at, updated_at
         FROM time_entries
         WHERE id = $1 AND user_id = $2"#
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("TimeEntry not found".to_string()))?;

    Ok(super::models::TimeEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        task_id: row.get("task_id"),
        start_time: row.get("start_time"),
        end_time: row.get("end_time"),
        duration_minutes: row.get("duration_minutes"),
        note: row.get("note"),
        manual: row.get("manual"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn create_time_entry(pool: &DbPool, entry: &super::models::CreateTimeEntry, user_id: &str) -> Result<super::models::TimeEntry, AppError> {
    let row = sqlx::query(
        r#"INSERT INTO time_entries (user_id, task_id, start_time, end_time,
            duration_minutes, note, manual)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING id, user_id, task_id, start_time, end_time,
            duration_minutes, note, manual, created_at, updated_at"#
    )
    .bind(user_id)
    .bind(&entry.task_id)
    .bind(&entry.start_time)
    .bind(&entry.end_time)
    .bind(entry.duration_minutes)
    .bind(&entry.note)
    .bind(entry.manual)
    .fetch_one(pool)
    .await?;

    Ok(super::models::TimeEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        task_id: row.get("task_id"),
        start_time: row.get("start_time"),
        end_time: row.get("end_time"),
        duration_minutes: row.get("duration_minutes"),
        note: row.get("note"),
        manual: row.get("manual"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn update_time_entry(pool: &DbPool, id: &str, user_id: &str, entry: &super::models::CreateTimeEntry) -> Result<super::models::TimeEntry, AppError> {
    let row = sqlx::query(
        r#"UPDATE time_entries
         SET task_id = $3, start_time = $4, end_time = $5,
             duration_minutes = $6, note = $7, manual = $8, updated_at = NOW()
         WHERE id = $1 AND user_id = $2
         RETURNING id, user_id, task_id, start_time, end_time,
            duration_minutes, note, manual, created_at, updated_at"#
    )
    .bind(id)
    .bind(user_id)
    .bind(&entry.task_id)
    .bind(&entry.start_time)
    .bind(&entry.end_time)
    .bind(entry.duration_minutes)
    .bind(&entry.note)
    .bind(entry.manual)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("TimeEntry not found".to_string()))?;

    Ok(super::models::TimeEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        task_id: row.get("task_id"),
        start_time: row.get("start_time"),
        end_time: row.get("end_time"),
        duration_minutes: row.get("duration_minutes"),
        note: row.get("note"),
        manual: row.get("manual"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn delete_time_entry(pool: &DbPool, id: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"DELETE FROM time_entries WHERE id = $1 AND user_id = $2"#
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("TimeEntry not found".to_string()));
    }
    Ok(())
}

// SpecialDays
pub async fn list_special_days(pool: &DbPool, user_id: &str) -> Result<Vec<super::models::SpecialDay>, AppError> {
    let rows = sqlx::query(
        r#"SELECT id, user_id, date_key, data, updated_at
         FROM special_days
         WHERE user_id = $1
         ORDER BY date_key"#
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    rows.iter().map(|row| {
        Ok(super::models::SpecialDay {
            id: row.get("id"),
            user_id: row.get("user_id"),
            date_key: row.get("date_key"),
            data: row.get("data"),
            updated_at: row.get("updated_at"),
        })
    }).collect()
}

pub async fn get_special_day(pool: &DbPool, date_key: &str, user_id: &str) -> Result<super::models::SpecialDay, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, date_key, data, updated_at
         FROM special_days
         WHERE date_key = $1 AND user_id = $2"#
    )
    .bind(date_key)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("SpecialDay not found".to_string()))?;

    Ok(super::models::SpecialDay {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        data: row.get("data"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn upsert_special_day(pool: &DbPool, entry: &super::models::UpsertSpecialDay, user_id: &str) -> Result<super::models::SpecialDay, AppError> {
    let id = format!("{}_{}", user_id, entry.date_key);
    let data_json = serde_json::to_string(&entry.data).unwrap_or_default();
    let row = sqlx::query(
        r#"INSERT INTO special_days (id, user_id, date_key, data)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()
         RETURNING id, user_id, date_key, data, updated_at"#
    )
    .bind(&id)
    .bind(user_id)
    .bind(&entry.date_key)
    .bind(&data_json)
    .fetch_one(pool)
    .await?;

    Ok(super::models::SpecialDay {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        data: row.get("data"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn delete_special_day(pool: &DbPool, date_key: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"DELETE FROM special_days WHERE date_key = $1 AND user_id = $2"#
    )
    .bind(date_key)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("SpecialDay not found".to_string()));
    }
    Ok(())
}

// Moods
pub async fn list_moods(pool: &DbPool, user_id: &str) -> Result<Vec<super::models::Mood>, AppError> {
    let rows = sqlx::query(
        r#"SELECT id, user_id, date_key, data, updated_at
         FROM moods
         WHERE user_id = $1
         ORDER BY date_key"#
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    rows.iter().map(|row| {
        Ok(super::models::Mood {
            id: row.get("id"),
            user_id: row.get("user_id"),
            date_key: row.get("date_key"),
            data: row.get("data"),
            updated_at: row.get("updated_at"),
        })
    }).collect()
}

pub async fn get_mood(pool: &DbPool, date_key: &str, user_id: &str) -> Result<super::models::Mood, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, date_key, data, updated_at
         FROM moods
         WHERE date_key = $1 AND user_id = $2"#
    )
    .bind(date_key)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("Mood not found".to_string()))?;

    Ok(super::models::Mood {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        data: row.get("data"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn upsert_mood(pool: &DbPool, entry: &super::models::UpsertMood, user_id: &str) -> Result<super::models::Mood, AppError> {
    let id = format!("{}_{}", user_id, entry.date_key);
    let data_json = serde_json::to_string(&entry.data).unwrap_or_default();
    let row = sqlx::query(
        r#"INSERT INTO moods (id, user_id, date_key, data)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, updated_at = NOW()
         RETURNING id, user_id, date_key, data, updated_at"#
    )
    .bind(&id)
    .bind(user_id)
    .bind(&entry.date_key)
    .bind(&data_json)
    .fetch_one(pool)
    .await?;

    Ok(super::models::Mood {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        data: row.get("data"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn delete_mood(pool: &DbPool, date_key: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"DELETE FROM moods WHERE date_key = $1 AND user_id = $2"#
    )
    .bind(date_key)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("Mood not found".to_string()));
    }
    Ok(())
}

// JournalEntries
pub async fn list_journal_entries(pool: &DbPool, user_id: &str) -> Result<Vec<super::models::JournalEntry>, AppError> {
    let rows = sqlx::query(
        r#"SELECT id, user_id, date_key, content, created_at, updated_at
         FROM journal_entries
         WHERE user_id = $1
         ORDER BY created_at DESC"#
    )
    .bind(user_id)
    .fetch_all(pool)
    .await?;

    rows.iter().map(|row| {
        Ok(super::models::JournalEntry {
            id: row.get("id"),
            user_id: row.get("user_id"),
            date_key: row.get("date_key"),
            content: row.get("content"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        })
    }).collect()
}

pub async fn get_journal_entry(pool: &DbPool, id: &str, user_id: &str) -> Result<super::models::JournalEntry, AppError> {
    let row = sqlx::query(
        r#"SELECT id, user_id, date_key, content, created_at, updated_at
         FROM journal_entries
         WHERE id = $1 AND user_id = $2"#
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("JournalEntry not found".to_string()))?;

    Ok(super::models::JournalEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        content: row.get("content"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn create_journal_entry(pool: &DbPool, entry: &super::models::CreateJournalEntry, user_id: &str) -> Result<super::models::JournalEntry, AppError> {
    let row = sqlx::query(
        r#"INSERT INTO journal_entries (user_id, date_key, content)
         VALUES ($1, $2, $3)
         RETURNING id, user_id, date_key, content, created_at, updated_at"#
    )
    .bind(user_id)
    .bind(&entry.date_key)
    .bind(&entry.content)
    .fetch_one(pool)
    .await?;

    Ok(super::models::JournalEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        content: row.get("content"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn update_journal_entry(pool: &DbPool, id: &str, user_id: &str, entry: &super::models::CreateJournalEntry) -> Result<super::models::JournalEntry, AppError> {
    let row = sqlx::query(
        r#"UPDATE journal_entries
         SET date_key = $3, content = $4, updated_at = NOW()
         WHERE id = $1 AND user_id = $2
         RETURNING id, user_id, date_key, content, created_at, updated_at"#
    )
    .bind(id)
    .bind(user_id)
    .bind(&entry.date_key)
    .bind(&entry.content)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| AppError::NotFound("JournalEntry not found".to_string()))?;

    Ok(super::models::JournalEntry {
        id: row.get("id"),
        user_id: row.get("user_id"),
        date_key: row.get("date_key"),
        content: row.get("content"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    })
}

pub async fn delete_journal_entry(pool: &DbPool, id: &str, user_id: &str) -> Result<(), AppError> {
    let result = sqlx::query(
        r#"DELETE FROM journal_entries WHERE id = $1 AND user_id = $2"#
    )
    .bind(id)
    .bind(user_id)
    .execute(pool)
    .await?;
    if result.rows_affected() == 0 {
        return Err(AppError::NotFound("JournalEntry not found".to_string()));
    }
    Ok(())
}
# Supabase Integration Design

**日期**: 2026-05-11
**状态**: 已批准，待实施

---

## 1. 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                             │
├─────────────────────────────────────────────────────────────┤
│  Presentation Layer (UI, Riverpod Providers)                │
├─────────────────────────────────────────────────────────────┤
│  Domain Layer (Entities, Repository Interfaces)              │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐ │
│  │   Drift     │◄──►│  Supabase   │◄──►│  Sync Manager   │ │
│  │  (Local)    │    │  Client     │    │  (Offline-first)│ │
│  └─────────────┘    └─────────────┘    └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

**核心策略**: 离线优先，本地 Drift 为主存储，Supabase 为远程备份。

---

## 2. 功能范围

| 模块 | 功能 |
|------|------|
| **Auth** | 邮箱/密码登录、注册、退出 |
| **Database** | 用户数据云端存储 |
| **Realtime** | 跨设备实时同步 |
| **Sync** | 离线优先同步策略 |

---

## 3. 同步流程

```
写操作:
  User Action → Drift (立即) → 标记 pending_sync=true → 后台同步到 Supabase

读操作:
  优先从 Drift 读取 → 后台检查 Supabase 更新 → 拉取最新（last-write-wins）

冲突解决:
  比较 updated_at → 以最新的为准覆盖旧数据
```

---

## 4. 认证流程 (Auth)

```
登录流程:
  1. 用户输入邮箱/密码
  2. 调用 supabase.auth.signInWithPassword()
  3. 成功 → 获取 session → 加载用户数据
  4. 失败 → 返回错误提示

注册流程:
  1. 用户输入邮箱/密码
  2. 调用 supabase.auth.signUp()
  3. 发送验证邮件 → 用户点击链接确认
  4. 确认后 → 自动登录

退出登录:
  1. 调用 supabase.auth.signOut()
  2. 清除本地 session
  3. 返回登录页面
```

---

## 5. 同步队列设计

**同步标志字段**:
- `pending_sync = true` → 待同步到远程
- `pending_sync = false` → 已同步

**同步触发时机**:
1. 应用启动时
2. 网络恢复时 (connectivity_check)
3. 手动触发 (下拉刷新)
4. 后台定时同步 (每 5 分钟)

---

## 6. Supabase 表结构

```sql
-- Projects
CREATE TABLE projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  parent_id UUID REFERENCES projects(id),
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  icon TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);

-- Tasks
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  project_id UUID REFERENCES projects(id) NOT NULL,
  parent_task_id UUID REFERENCES tasks(id),
  title TEXT NOT NULL,
  description TEXT,
  priority INT DEFAULT 2,
  status INT DEFAULT 0,
  due_date TIMESTAMPTZ,
  tags TEXT DEFAULT '',
  estimated_minutes INT,
  actual_minutes INT,
  is_recurring BOOLEAN DEFAULT false,
  recurring_rule TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);

-- Time Entries
CREATE TABLE time_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users NOT NULL,
  task_id UUID REFERENCES tasks(id) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration_minutes INT,
  note TEXT DEFAULT '',
  manual BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  deleted_at TIMESTAMPTZ
);

-- RLS Policies
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can only access own projects" ON projects
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own tasks" ON tasks
  FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can only access own time entries" ON time_entries
  FOR ALL USING (auth.uid() = user_id);
```

---

## 7. 目录结构

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/
│   ├── theme/
│   └── supabase/
│       └── supabase_client.dart
├── data/
│   ├── datasources/
│   │   ├── local/
│   │   │   └── app_database.dart
│   │   └── remote/
│   │       └── supabase_datasource.dart
│   └── repositories/
│       ├── project_repository_impl.dart
│       ├── task_repository_impl.dart
│       └── time_entry_repository_impl.dart
├── domain/
│   ├── entities/
│   └── repositories/
└── features/
    ├── auth/
    │   ├── presentation/
    │   │   ├── providers/
    │   │   │   └── auth_provider.dart
    │   │   └── screens/
    │   │       ├── login_screen.dart
    │   │       └── register_screen.dart
    │   └── domain/
    │       └── auth_service.dart
    └── sync/
        ├── data/
        │   └── sync_manager.dart
        └── presentation/
            └── providers/
                └── sync_status_provider.dart
```

---

## 8. 错误处理

| 场景 | 处理方式 |
|------|----------|
| 网络断开 | 继续本地操作，标记 pending_sync |
| 同步失败 | 重试 3 次，指数退避 |
| 认证过期 | 自动刷新 token，刷新失败跳转登录 |
| 冲突 | last-write-wins，比较 updated_at |
| Supabase 不可用 | 本地优先，保证核心功能可用 |

---

## 9. 实施优先级

### Phase 1: 认证 (Auth)
1. Supabase 客户端初始化
2. 登录/注册屏幕
3. Auth Provider
4. 会话管理

### Phase 2: 数据同步
1. Supabase Datasource
2. Sync Manager
3. Repository 改造（支持同步）
4. Realtime Listener

### Phase 3: 完整集成
1. Edge Functions (统计计算)
2. 同步状态 UI
3. 冲突处理 UI

# Task Manager - 个人时间/任务/项目管理应用

**日期**: 2026-05-10
**状态**: 设计完成，待用户审批

---

## 1. 概述

全平台（iOS/Android/Web/桌面）个人生产力应用，涵盖任务管理、项目管理、时间追踪、习惯追踪、目标管理和报表统计。

**技术栈**:
- 前端: Flutter (单代码库)
- 后端: Supabase (Postgres + Realtime + Auth + Edge Functions)
- 本地存储: Drift (SQLite)
- 状态管理: Riverpod / flutter_riverpod
- 架构: Clean Architecture

---

## 2. 功能范围

### 2.1 核心模块

| 模块 | 功能 |
|------|------|
| **任务管理** | 创建/编辑/删除任务，优先级/截止日期/标签，子任务，循环任务 |
| **项目管理** | 层级目录结构 (项目→子项目→任务)，项目概览 |
| **时间追踪** | 手动计时 + 自动记录，计时历史，时间块编辑 |
| **习惯追踪** | 习惯打卡，日历视图，连续天数统计 |
| **目标管理** | 长期目标 → 里程碑 → 任务，进度可视化 |
| **报表统计** | 时间分布，任务完成率，习惯达成率，热力图 |

### 2.2 离线能力

- 所有核心功能离线可用
- 本地 Drift 数据库作为主存储
- 网络恢复后自动与 Supabase 同步
- 冲突处理策略: 最后写入优先 (last-write-wins)

---

## 3. 数据模型

### 3.1 核心实体

```
User
  └── Profile (设置、主题偏好)

Project (层级目录)
  ├── id, name, parent_id (nullable), color, icon, created_at
  └── has sub_projects[]

Task
  ├── id, project_id, parent_task_id (nullable)
  ├── title, description, priority (1-4), status, due_date
  ├── tags[], estimated_minutes, actual_minutes
  ├── is_recurring, recurring_rule, subtasks[]
  └── created_at, updated_at

TimeEntry
  ├── id, task_id, start_time, end_time, duration_minutes
  └── note, manual (boolean)

Habit
  ├── id, name, frequency (daily/weekly), target_days[]
  ├── current_streak, longest_streak, created_at

Goal
  ├── id, title, description, target_date
  ├── milestones[], progress_percent
  └── linked_tasks[]

Tag
  └── id, name, color
```

---

## 4. 技术架构

### 4.1 分层结构

```
lib/
├── core/           # 通用工具、常量、主题
├── features/       # 按功能模块组织
│   ├── tasks/
│   ├── projects/
│   ├── time_tracking/
│   ├── habits/
│   ├── goals/
│   └── reports/
├── data/           # 数据层 (repositories, data sources)
├── domain/         # 领域层 (entities, use cases)
└── presentation/   # 表现层 (UI, widgets, providers)
```

### 4.2 离线同步策略

1. **写操作**: 优先写入本地 Drift → 标记待同步 → 后台同步到 Supabase
2. **读操作**: 优先从本地 Drift 读取 → 后台更新最新数据
3. **冲突**: 使用 `updated_at` 字段，最后写入优先
4. **同步触发**: 应用启动 + 网络恢复 + 手动触发

### 4.3 Supabase 集成

- **Auth**: 邮箱/密码登录，magic link，支持 SSO
- **Database**: Postgres，所有表开启 RLS (Row Level Security)
- **Realtime**: 跨设备同步通知
- **Edge Functions**: 复杂业务逻辑 (如统计计算)

---

## 5. 视觉设计

### 5.1 风格: 霓虹点缀深色风格

- **背景色**: `#0d0d1a` (深黑)
- **表面色**: `#1a1a2e` (深灰蓝)
- **主强调色**: `#00ff9f` (薄荷绿)
- **次强调色**: `#00d4ff` (青色)
- **文字色**: `#e0e0e0` (亮灰白)
- **边框色**: `#2a2a4a`
- **成功色**: `#00ff9f`
- **警告色**: `#ffcc00`
- **错误色**: `#ff4757`

### 5.2 字体

- 界面: 系统默认无衬线 (SF Pro / Roboto)
- 代码/数字: 等宽字体 (JetBrains Mono / SF Mono)

### 5.3 间距系统

- 基准单位: 4px
- 间距: 4, 8, 12, 16, 24, 32, 48
- 圆角: 4px (小), 8px (中), 12px (大), 16px (卡片)

### 5.4 组件设计

- 卡片: 背景 `#1a1a2e`，1px 边框 `#2a2a4a`，圆角 12px
- 按钮: 背景透明 + 霓虹色边框，hover 时填充霓虹色
- 输入框: 深色背景 + 细边框，聚焦时边框变霓虹色
- 进度条: 霓虹渐变填充

---

## 6. 响应式布局

### 6.1 断点

| 设备 | 宽度 |
|------|------|
| 手机 | < 600px |
| 平板 | 600-1024px |
| 桌面 | > 1024px |

### 6.2 移动端

- 单列布局，底部导航
- 抽屉式侧边栏 (左滑呼出)
- 任务列表全屏卡片

### 6.3 桌面端

- 三栏布局: 侧边导航 | 任务列表 | 详情面板
- 顶栏: 搜索 + 快捷操作
- 可调整的面板宽度

---

## 7. 待确认事项

以下问题需要在实现前确认:

1. **数据迁移策略**: 从其他工具 (Todoist/Asana) 导入数据?
2. **多设备同步冲突UI**: 冲突时用户如何解决?
3. **团队协作**: 是否需要多用户共享项目? (当前设计为单人使用)
4. **数据导出**: 是否需要导出为 CSV/JSON?

---

## 8. 实现优先级

### Phase 1: MVP (核心任务 + 时间)
1. 项目管理 (层级目录)
2. 任务 CRUD
3. 时间追踪 (手动 + 自动)
4. 离线存储

### Phase 2: 增强 (习惯 + 目标)
5. 习惯追踪
6. 目标管理

### Phase 3: 完整套件
7. 报表统计
8. 跨设备同步
9. 高级视图 (日历)

---

设计版本: 1.0
下一步: 等待用户审批后进入实施规划阶段
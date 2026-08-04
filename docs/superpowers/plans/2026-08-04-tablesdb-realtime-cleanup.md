# Plan: TablesDB migration + Realtime + cleanup (released as 0.13.0)

> Archived plan for the 2026-08-04 session that produced PRs #8 (cleanup), #9 (TablesDB), #10 (Realtime) and the v0.13.0 release. Original interactive version: `~/.claude/plans/jazzy-juggling-marshmallow.md`.

## Context

项目扫描时识别出 4 项待处理问题，按依赖关系拆为 3 个顺序 PR：

1. **文档与代码不一致 + backend/ 残留**：FEATURES.md 仍写 Supabase；`backend/` 是 v0.10.0 引入的 Rust+Axum+PostgreSQL HTTP 服务，v0.11.0 切换到 Appwrite 后已无用但从未删除。
2. **Appwrite `Databases` 弃用**：项目用 `appwrite: 21.4.0` 的 `Databases` API（`createDocument`/`updateDocument`/`listDocuments`），所有调用点上方都有 `// ignore_for_file: deprecated_member_use`。SDK 21.4.0 提供 `TablesDB` 作为推荐替代。
3. **同步缺少实时推送**：当前 5 分钟轮询 + push-before-pull，编辑 → 远端到对端有 5 分钟延迟。Appwrite SDK 21.4.0 自带 `Realtime` WebSocket 订阅。

**目标**：清掉 3 项技术债，让代码与文档一致，消除 `deprecated_member_use` 抑制，将多端编辑延迟从 ≤5min 降到 ≤1s。

用户决策（已确认）：
- 提交方式：3 个顺序 PR
- Realtime 合并策略：本地 `pendingSync=true` 行跳过远端事件写入（保留本地为真源，避免静默丢离线编辑）

---

## PR 1 — 清理：删 backend/ + 修 FEATURES.md

### 改动

| 文件 | 操作 |
|------|------|
| `backend/` | 删除整个目录（含 `Cargo.toml`、`Dockerfile`、`docker-compose.yml`、`migrations/`、`src/`、空 `logs.txt`） |
| `run_api_tests.bat` | 删除（仅引用 backend/ 的根级脚本） |
| `FEATURES.md:104` | `- Supabase 远程数据同步` → `- Appwrite 远程数据同步` |
| `FEATURES.md:113` | `- **实时同步**：Supabase PostgreSQL` → `- **实时同步**：Appwrite Realtime（WebSocket 推送）` |

### 不动

- `CHANGELOG.md` — 历史记录，正确，不改
- `lib/**` 中的 Supabase 历史注释（`appwrite_client.dart:6` 等 7 处）— 记录迁移历史，不改
- `docs/superpowers/specs/*.md`、`docs/superpowers/plans/*.md` — 历史设计文档，不改
- `.claude/settings.local.json` 中的 `supabase`/`PostgrestFilterBuilder` 预批准模式 — 失效但无害，不动

### 验证

```bash
# 1. 确认无残留引用
grep -r "backend/" lib/ scripts/ packaging/ .github/ 2>/dev/null   # 应为空
grep -r "supabase" FEATURES.md                                       # 应为空（CHANGELOG 仍会有历史项，是正常的）
# 2. 静态分析
flutter analyze lib/
# 3. 完整测试
flutter test
# 4. 确认 FEATURES.md 与实际栈一致
head -110 FEATURES.md | grep -A2 "13. 同步"
```

### 风险

零。`backend/` 从未被 Flutter 代码引用；`run_api_tests.bat` 仅开发者本地使用。

---

## PR 2 — 迁移 Appwrite `Databases` → `TablesDB`

### 核心依据（来自 SDK 21.4.0 调查）

`~/.pub-cache/hosted/pub.dev/appwrite-21.4.0/lib/services/tables_db.dart` 暴露 `TablesDB(client)`，方法签名：

```dart
Future<RowList> listRows({required databaseId, required tableId, List<String>? queries})
Future<Row>     createRow({required databaseId, required tableId, required rowId, required Map data})
Future<Row>     updateRow({required databaseId, required tableId, required rowId, Map? data})
Future<Row>     upsertRow({required databaseId, required tableId, required rowId, Map? data})  // 替换手动 409 处理
Future<dynamic> deleteRow({required databaseId, required tableId, required rowId})
```

`Query.equal`、`Query.isNull`、`Query.orderAsc/Desc` 等所有方法完全兼容（共享 `Query` 类）。`$createdAt`/`$updatedAt` 在 `Row.data` 中仍然存在。

### 改动

| 文件 | 改动 |
|------|------|
| `lib/data/datasources/remote/appwrite_datasource.dart` | **主改动**。`Databases` → `TablesDB`；`collectionId` → `tableId`；`documentId` → `rowId`；`createDocument/updateDocument/listDocuments/deleteDocument` → `createRow/updateRow/listRows/deleteRow`；`result.documents` → `result.rows`；`_docToRow` 改名为 `_rowToMap` 并改用 `Row` 模型；删除 `// ignore_for_file: deprecated_member_use`；**用 `upsertRow` 替换 `_upsertDocument` 中的 try-create-then-update 逻辑**（消除 6 处调用点的异常驱动控制流） |
| `lib/data/datasources/remote/user_scoped_query.dart` | 仅注释更新（`listDocuments` → `listRows`），行为不变。`buildUserScopedQueries` / `buildLiveUserScopedQueries` 签名稳定 |
| `test/unit/appwrite_datasource_test.dart` | 仅注释更新（`listDocuments` → `listRows`），断言不变 |
| `CLAUDE.md` 第 47-49 行的"6 collections"措辞 | "collections" → "collections/tables"（过渡期表述，避免误导；服务端 `Databases` 仍可寻址旧 collection） |

**不改**（已确认稳定）：
- `lib/data/datasources/remote/remote_datasource.dart` — 抽象接口不含 SDK 类型
- `lib/data/datasources/remote/remote_datasource_factory.dart` — 工厂构造签名不变
- `test/unit/sync_manager_test.dart` — mock 的是 `RemoteDatasource` 接口
- 任何 repository / provider / screen / widget

### 关键代码变更模式

```dart
// 之前
Databases get _databases => Databases(_client);
Future<void> _upsertDocument({required String collectionId, required String documentId, required Map<String, dynamic> data}) async {
  try {
    await _databases.createDocument(databaseId: databaseId, collectionId: collectionId, documentId: documentId, data: data);
  } on AppwriteException catch (e) {
    if (e.code == 409) {
      await _databases.updateDocument(databaseId: databaseId, collectionId: collectionId, documentId: documentId, data: data);
    } else { rethrow; }
  }
}

// 之后
TablesDB get _tablesDB => TablesDB(_client);
Future<void> _upsertRow({required String tableId, required String rowId, required Map<String, dynamic> data}) =>
    _tablesDB.upsertRow(databaseId: databaseId, tableId: tableId, rowId: rowId, data: data);

// 之前
final result = await _databases.listDocuments(databaseId: databaseId, collectionId: 'projects', queries: ...);
return result.documents.map(_docToRow).toList();

// 之后
final result = await _tablesDB.listRows(databaseId: databaseId, tableId: 'projects', queries: ...);
return result.rows.map(_rowToMap).toList();
```

### 服务端要求

- Appwrite 服务端必须 ≥1.8.x（已就绪：CHANGELOG 显示服务端版本是 Appwrite 1.8）
- 现有 6 个 collection 的 ID/属性/索引保持不变；`TablesDB` 通过 `/tablesdb/...` 端点寻址同一组资源
- **操作前**：在 self-hosted Appwrite 控制台对 6 个 collection 各执行一次 `upsertRow` 烟雾测试（用 Postman 或 curl），确认 endpoints 通畅
- **如回滚**：恢复原文件即可（git revert），服务端 schema 不变

### 验证

```bash
# 1. 静态分析：deprecated_member_use 警告应消失
flutter analyze lib/data/datasources/remote/

# 2. 现有测试应全过
flutter test test/unit/appwrite_datasource_test.dart
flutter test

# 3. 真实 Appwrite 烟雾测试（人工，10 min）：
#    a. 启动 app
#    b. 创建一个 task → 验证服务端可见
#    c. 离线编辑 → 重连 → 验证 push 成功
#    d. 删除 task → 验证服务端 deleted_at 写入
#    e. 跨设备 pull → 验证数据正确
```

### 风险

中低。变更集中在一个文件；`upsertRow` 替换 try-catch 简化了逻辑；服务端 API 兼容已由 SDK 21.4.0 changelog 保证。主要风险是 self-hosted 服务端版本若 <1.8 会失败 — 提交前用 `upsertRow` 烟雾测试确认。

---

## PR 3 — Realtime 订阅 + 合并策略

### 核心依据（来自 SDK 21.4.0 调查）

`Realtime(client).subscribe([Channel.database('dbId').collection('colId')], queries: [...])` 返回 `RealtimeSubscription`（`Stream<RealtimeMessage>` + `close()`）。事件 payload 形如 REST Document 主体（含 `user_id`）。服务端通过 Cookie 鉴权 WebSocket（`AppwriteClient` 已用 `Account.createEmailSession` 建立 session cookie）。

### 合并策略（用户已确认）

**本地 `pendingSync=true` 是真源，Realtime 事件不写入。**

理由：用户离线编辑后未推送的本地修改优先级最高。Realtime 事件在 `pendingSync=true` 行上做"丢给"处理——日志记录一次 `skip: pendingSync=true`，并在下一个 sync 周期由 `syncAll()` 的 push 阶段自然解决。

**所有其他行**：Realtime 事件直接写入（覆盖），`pendingSync` 强制置 `false`（保留现有 `upsertXFromRemote` 行为）。

### 改动

| 文件 | 改动 |
|------|------|
| `lib/core/services/appwrite_client.dart` | 在已建 session 的 `Client` 上新增 `Realtime get realtime => Realtime(_client);` |
| `lib/data/datasources/local/app_database.dart` | 在 `upsertProjectFromRemote` / `upsertTaskFromRemote` / `upsertTimeEntryFromRemote` 入口加守卫：若 `pendingSync=true`，返回 `false` 表示"已跳过"；现有行为不变 |
| `lib/data/repositories/{task,project}_repository_impl.dart` | 不变（push 仍由 `SyncManager` 驱动） |
| `lib/features/{journal,mood,special_days}/data/*_repository_impl.dart` | 新增 `applyRemoteUpsertEntry(...)` / `applyRemoteDeleteEntry(...)`（per-key 写入，**不**整 cache 覆盖）。`pullFromRemote` 保持完整快照语义 |
| `lib/data/datasources/remote/remote_datasource.dart` | 抽象接口不变（Realtime 是 `Client` 的能力，由 `SyncManager` 直接持有 `Realtime`） |
| `lib/features/sync/data/sync_manager.dart` | **核心改动**：构造时通过 `Realtime(client).subscribe(...)` 订阅 6 个 collection 的 `create/update/delete` 事件；handler 路由到对应 repo / DB；handler 内调用 `upsertXFromRemote` 失败（返回 false）时 logger 记录 skip；`dispose()` 中调用 `_realtimeSub?.close()` |
| `lib/core/constants/app_constants.dart` | 新增 `realtimeChannels = ['projects', 'tasks', 'time_entries', 'special_days', 'moods', 'journal_entries']`（便于测试和复用） |
| `test/unit/sync_manager_test.dart` | 新增测试：(a) `pendingSync=true` 时 Realtime handler 跳过写入；(b) `dispose` 同时关闭 `RealtimeSubscription`；(c) 现有 2 个测试保持通过 |
| `test/unit/appwrite_datasource_test.dart` | 不变 |

### 关键设计要点

1. **单一订阅**：每个 collection 一个 channel，覆盖 create/update/delete。`Realtime` SDK 共享 WebSocket，6 个 channel 不增加连接数。
2. **服务端过滤**：`subscribe(channels, queries: [Query.equal('user_id', userId)])` — 在 Appwrite 端按用户过滤，避免接收他人的事件。
3. **生命周期**：在 `syncManagerProvider` 的 `ref.onDispose` 中调用 `_realtimeSub?.close()`，与现有 `SyncManager.dispose()` 一致。
4. **竞态保护**：维持现有 5-min 定时器和 push-before-pull。Realtime 与 5-min pull 是补充关系（Realtime 加速日常变化感知，pull 保证最终一致性 / 处理 push 漏掉的对端删除）。**不**做"sync mutex" — Realtime 事件是幂等写入（`insertOnConflictUpdate`），重复无害；status 广播可能出现两次 success，不影响业务。
5. **墓碑兼容**：现有 `upsertXFromRemote` 已正确处理 `deleted_at`（`app_database.dart:235`），Realtime 的 `delete` 事件带 `deleted_at`，复用同一路径。
6. **Auth**：Cookie 在 WebSocket upgrade 时由 SDK 的 `CookieManager` 自动附加（`realtime_io.dart:33`）。前提：用户已登录且 session cookie 存在 — `SyncManager` 构造时机已保证（依赖 `remoteDatasourceProvider` → 依赖 `userIdProvider` → 依赖 `authStateProvider.authenticated`）。

### 关键代码变更模式

```dart
// app_database.dart - 新增守卫
Future<bool> upsertTaskFromRemote(Map<String, dynamic> data) async {
  final id = data['id'] as String;
  final existing = await (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  if (existing != null && existing.pendingSync) {
    Logger.d('skip remote upsert: $id pendingSync=true');
    return false;
  }
  // ... 现有 insertOnConflictUpdate 逻辑
  return true;
}

// sync_manager.dart - 新增
RealtimeSubscription? _realtimeSub;
static const _channels = ['projects', 'tasks', 'time_entries', 'special_days', 'moods', 'journal_entries'];

void _initRealtime() {
  final client = (_remoteDs as AppwriteDatasource).realtimeClient; // 需暴露
  final realtime = Realtime(client);
  _realtimeSub = realtime.subscribe(
    _channels.map((c) => 'databases.${AppConstants.appwriteDatabaseId}.collections.$c.documents').toList(),
  );
  _realtimeSub!.stream.listen(_onRealtimeEvent);
}

Future<void> _onRealtimeEvent(RealtimeMessage msg) async {
  final collection = _extractCollection(msg.channels);
  if (collection == null) return;
  if ((msg.payload['user_id'] ?? '') != _userId) return;
  final event = msg.events.first;  // 'databases.*.collections.*.documents.*.create|update|delete'
  if (event.endsWith('.delete')) {
    // soft-delete via deletedAt，或 hard-delete（time_entries / journal）
    // 走 repository 的 applyRemoteDelete
  } else {
    // upsert via existing upsertXFromRemote
  }
}

void dispose() {
  _realtimeSub?.close();
  // ... 现有 dispose 逻辑
}
```

### 验证

```bash
# 1. 静态分析
flutter analyze lib/

# 2. 单元测试（新增 3 个）
flutter test test/unit/sync_manager_test.dart

# 3. 完整测试
flutter test

# 4. 端到端（人工）：
#    a. 启动 app A（macOS）+ app B（Android），同一账号
#    b. A 创建 task → B 1s 内应见（无 5 min 等待）
#    c. A 断网编辑 task title → A 重连后 B 同步更新（push 走原路径）
#    d. A 断网编辑 → B 此时编辑同一 task → A 重连 → A 的本地修改保留（pendingSync gate 验证）
#    e. A 删除 task → B 1s 内应消失
#    f. 退出登录 → Realtime subscription 应关闭（ref.onDispose 触发）
#    g. macOS 重启 app → 初次同步 + Realtime 重连正常
```

### 风险

中。
- **Auth 失效**：若 WebSocket cookie 未带上，事件会被服务端过滤为 anonymous。验证点 4a/4b 会立即暴露。
- **大流量**：用户量大时 6 个 collection × N 用户的 Realtime 流量对 self-hosted Appwrite 是负载。考虑 PR3 后加采样或只在用户进入 app 时启用。
- **Realtime SDK 在某些平台可能不稳定**：若发现 macOS 或 Linux 桌面 WebSocket 频繁断开，需在 `_initRealtime` 加 reconnect 退避（PR 范围外，可后续处理）。

---

## 实施顺序

```
PR 1 (clean)        PR 2 (TablesDB)        PR 3 (Realtime)
  └─ 5 min            └─ 1-2 h                └─ 3-4 h
     合并 → 服务端烟雾测试 → 合并 → 端到端验证
```

每个 PR 独立 reviewable、独立 revertable。PR 2 是 PR 3 的前置（PR 3 改 `SyncManager` 路由到 `_tablesDB`/`_realtime`，与 PR 2 一起形成"新 SDK 全面启用"主题）。

---

## 关键文件清单

| 路径 | PR | 性质 |
|------|----|------|
| `backend/` | 1 | 删除 |
| `run_api_tests.bat` | 1 | 删除 |
| `FEATURES.md` | 1 | 2 行修正 |
| `lib/data/datasources/remote/appwrite_datasource.dart` | 2 | 主体迁移 |
| `lib/data/datasources/remote/user_scoped_query.dart` | 2 | 注释 |
| `test/unit/appwrite_datasource_test.dart` | 2 | 注释 |
| `CLAUDE.md` | 2 | 措辞 |
| `lib/core/services/appwrite_client.dart` | 3 | 暴露 `Realtime` |
| `lib/data/datasources/local/app_database.dart` | 3 | `pendingSync` 守卫 |
| `lib/features/{journal,mood,special_days}/data/*_repository_impl.dart` | 3 | per-key upsert/delete |
| `lib/features/sync/data/sync_manager.dart` | 3 | Realtime 生命周期 + 路由 |
| `lib/core/constants/app_constants.dart` | 3 | 频道列表常量 |
| `test/unit/sync_manager_test.dart` | 3 | 新增 3 测试 |

## 可复用资源

- `lib/core/utils/retry_with_backoff.dart` — Realtime 重连退避（PR 3 范围内或后续）
- `lib/core/utils/logger.dart` — 跳过事件日志
- `lib/core/utils/json_cache_store.dart` — journal/mood/special_days per-key cache
- `lib/core/widgets/async_error_view.dart` — 不适用

## 验证汇总

每个 PR 独立验证：
1. `flutter analyze lib/` — 必须 0 警告
2. `flutter test` — 必须全过
3. PR 1 + PR 2：人工烟雾测试 1 个创建/编辑/删除循环
4. PR 3：人工端到端多设备测试（含离线编辑 conflict 场景 4d）

## 不在本方案范围内

- Realtime WebSocket 重连退避策略（发现断线严重时再加）
- 冲突解决的语义化提升（用户已选择 skip 而非 LWW/multi-master merge）
- Appwrite TablesDB 服务端实际版本验证（提交 PR 2 前人工 curl 一次确认）
- self-hosted Appwrite 服务端升级（CLAUDE.md 显示已在 1.8.x）

## Post-release verification (added 2026-08-04)

- Appwrite self-hosted server is 1.9.0 (not 1.8.x as initially assumed; SDK 21.4.0 is still compatible)
- 1.9+ requires session via `Cookie: a_session_<projectId>=<token>` — `X-Appwrite-Session` header alone is silently dropped to guest role
- `scripts/smoke_tablesdb.sh` passed 6/6 collections on the live instance after `Role.users()` was added to collection CRUD permissions
- Homebrew Cask synced to `craftor/homebrew-task-manager` at `c980c16` (tap default branch is `main`, not `master`) — `brew reinstall --cask task-manager` now serves 0.13.0

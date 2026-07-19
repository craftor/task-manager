# One-shot sync diagnostics: compares what the Appwrite server holds for the
# currently signed-in Windows session vs. what landed in the local Drift DB.
# Reads the app's own persisted session cookie (PersistCookieJar FileStorage)
# — never prints the cookie itself.
import json
import os
import re
import sqlite3
import urllib.parse
import urllib.request

BASE = "http://o.21up.cn:6080/v1"
PROJ = "6a20e0b10013cae75d20"
DBID = "6a20eeaa002f0f294ab9"
COLLECTIONS = ["projects", "tasks", "time_entries", "special_days", "moods", "journal_entries"]

# --- session cookie from the app's cookie jar ---
jar_path = os.path.expanduser(r"~\Documents\cookies\ie0_ps1\.domains")
with open(jar_path, encoding="utf-8") as f:
    jar = json.load(f)
cookies = []
for _host, paths in jar.items():
    for _p, entries in paths.items():
        for _name, raw in entries.items():
            cookies.append(raw.split(";")[0])
COOKIE_HDR = "; ".join(cookies)


def get(path, queries=None):
    url = BASE + path
    if queries:
        url += "?" + urllib.parse.urlencode([("queries[]", q) for q in queries])
    req = urllib.request.Request(
        url, headers={"X-Appwrite-Project": PROJ, "Cookie": COOKIE_HDR}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        raise RuntimeError(f"HTTP {e.code}: {body}") from e


print("=== REMOTE (as the app's Windows session) ===")
acc = get("/account")
uid = acc["$id"]
print(f"ACCOUNT id={uid} email={acc.get('email')} name={acc.get('name')}")

for coll in COLLECTIONS:
    try:
        visible = get(f"/databases/{DBID}/collections/{coll}/documents")["total"]
    except Exception as e:
        visible = f"ERR {type(e).__name__}: {e}"
    try:
        mine = get(
            f"/databases/{DBID}/collections/{coll}/documents",
            [f'equal("user_id","{uid}")', "limit(1)"],
        )["total"]
    except Exception as e:
        mine = f"ERR {type(e).__name__}: {e}"
    print(f"  {coll:16s} visible(no_query)={visible}  user_id_match={mine}")

print("\n=== exact app queries (SDK JSON query format) ===")


def jq(method, attribute=None, values=None):
    q = {"method": method}
    if attribute is not None:
        q["attribute"] = attribute
    if values is not None:
        q["values"] = values
    return json.dumps(q, separators=(",", ":"))


APP_QUERIES = {
    "projects": [jq("equal", "user_id", [uid]), jq("isNull", "deleted_at"), jq("orderAsc", "$createdAt")],
    "tasks": [jq("equal", "user_id", [uid]), jq("isNull", "deleted_at"), jq("orderAsc", "$createdAt")],
    "time_entries": [jq("equal", "user_id", [uid]), jq("orderAsc", "start_time")],
    "special_days": [jq("equal", "user_id", [uid]), jq("orderAsc", "date_key")],
    "moods": [jq("equal", "user_id", [uid]), jq("orderAsc", "date_key")],
    "journal_entries": [jq("equal", "user_id", [uid]), jq("orderDesc", "$createdAt")],
}
for coll, queries in APP_QUERIES.items():
    try:
        res = get(f"/databases/{DBID}/collections/{coll}/documents", queries)
        print(f"  {coll:16s} OK total={res['total']}")
    except Exception as e:
        print(f"  {coll:16s} FAIL {e}")

print("\n=== special_days with EXACT app headers ===")
req = urllib.request.Request(
    f"{BASE}/databases/{DBID}/collections/special_days/documents"
    + "?"
    + urllib.parse.urlencode(
        [
            ("queries[]", jq("equal", "user_id", [uid])),
            ("queries[]", jq("orderAsc", "date_key")),
        ]
    ),
    headers={
        "content-type": "application/json",
        "x-sdk-name": "Flutter",
        "x-sdk-platform": "client",
        "x-sdk-language": "flutter",
        "x-sdk-version": "21.4.0",
        "X-Appwrite-Response-Format": "1.8.0",
        "X-Appwrite-Project": PROJ,
        "Origin": "appwrite-windows://com.example.task_manager",
        "user-agent": "com.example.task_manager/0.12.5 (Windows NT; DESKTOP)",
        "Cookie": COOKIE_HDR,
    },
)
try:
    with urllib.request.urlopen(req, timeout=15) as r:
        body = r.read()
        print(f"  status={r.status} content-type={r.headers.get('content-type')}")
        print(f"  body[:200]={body[:200]!r}")
        parsed = json.loads(body)
        print(f"  parsed type={type(parsed).__name__}", end="")
        if isinstance(parsed, dict):
            print(f" total={parsed.get('total')}")
        else:
            print(f" value={str(parsed)[:100]!r}")
except urllib.error.HTTPError as e:
    print(f"  HTTP {e.code}: {e.read()[:300]!r}")

for coll in ["projects", "tasks", "special_days"]:
    print(f"--- {coll} ---")
    try:
        res = get(f"/databases/{DBID}/collections/{coll}/documents")
        for d in res["documents"][:5]:
            if coll == "special_days":
                data = d.get("data")
                print(
                    f"  date_key={d.get('date_key')!r} user_id={d.get('user_id')!r} "
                    f"data_type={type(data).__name__} data={str(data)[:80]!r}"
                )
            elif coll == "projects":
                print(
                    f"  id={d.get('$id')!r} name={d.get('name')!r} user_id={d.get('user_id')!r} "
                    f"is_default={d.get('is_default')!r} deleted_at={d.get('deleted_at')!r}"
                )
            else:
                print(
                    f"  id={d.get('$id')!r} title={d.get('title')!r} user_id={d.get('user_id')!r} "
                    f"project_id={d.get('project_id')!r} deleted_at={d.get('deleted_at')!r}"
                )
    except Exception as e:
        print(f"  ERR {type(e).__name__}: {e}")

print("\n=== LOCAL Drift DB ===")
consts = open(
    r"D:\ai_proj\task-manager\lib\core\constants\app_constants.dart", encoding="utf-8"
).read()
m = re.search(r"dbName\s*=\s*'([^']+)'", consts)
db_path = os.path.expanduser("~/Documents/" + m.group(1))
print(f"path={db_path} exists={os.path.exists(db_path)}")
if os.path.exists(db_path):
    con = sqlite3.connect(db_path)
    tables = [
        r[0]
        for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")
        if not r[0].startswith("_") and r[0] != "sqlite_sequence"
    ]
    for t in tables:
        n = con.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
        extra = ""
        cols = [c[1] for c in con.execute(f'PRAGMA table_info("{t}")')]
        for cand in ("pending_sync", "pendingSync"):
            if cand in cols:
                p = con.execute(
                    f'SELECT COUNT(*) FROM "{t}" WHERE "{cand}"=1'
                ).fetchone()[0]
                extra = f" (pendingSync={p})"
        print(f"  {t}: {n}{extra}")
    con.close()

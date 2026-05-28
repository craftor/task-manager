@echo off
echo Running migration...
docker run --rm -v "E:/01-AI-Proj/task-manager/backend/migrations:/migrations" postgres:16-alpine psql "postgresql://task_manager:MX5F6bXYcM6AGySK@a.21up.cn:1234" -f /migrations/001_init.sql
echo Migration complete
echo.
echo Testing API endpoints...
echo.
echo GET /api/projects (with user header):
curl -s -H "x-user-id: test-user" http://localhost:8080/api/projects
echo.
echo POST /api/projects:
curl -s -X POST -H "x-user-id: test-user" -H "Content-Type: application/json" http://localhost:8080/api/projects -d "{\"name\":\"Test Project\",\"color\":\"#00ff00\",\"icon\":\"star\"}"
echo.
echo GET /api/tasks:
curl -s -H "x-user-id: test-user" http://localhost:8080/api/tasks
echo.
echo GET /api/time-entries:
curl -s -H "x-user-id: test-user" http://localhost:8080/api/time-entries
echo.
echo GET /api/special-days:
curl -s -H "x-user-id: test-user" http://localhost:8080/api/special-days
echo.
echo GET /api/moods:
curl -s -H "x-user-id: test-user" http://localhost:8080/api/moods
echo.
echo GET /api/journal-entries:
curl -s -H "x-user-id: test-user" http://localhost:8080/api/journal-entries
echo.
echo GET /api/projects (no auth):
curl -s http://localhost:8080/api/projects
pause
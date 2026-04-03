# VPS Deploy Note

The latest Docker-based VPS deployment guide is:

`../VPS_DOCKER_DEPLOY.md`

Summary of architecture:

- Host Nginx terminates HTTPS for `example.com`.
- Host Nginx proxies `/` to `127.0.0.1:17001` (Flutter container).
- Host Nginx proxies `/api/` and `/hubs/room` to `127.0.0.1:17000` (ASP.NET container).
- PostgreSQL runs in Docker and is not directly exposed to the internet.

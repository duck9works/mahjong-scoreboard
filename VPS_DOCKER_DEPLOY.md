# VPS Docker Deploy

This setup runs all app services with Docker on the VPS and keeps TLS/domain routing on host Nginx.

- Host Nginx handles `example.com` and HTTPS.
- Docker `client` serves Flutter Web on `127.0.0.1:17001`.
- Docker `api` serves ASP.NET WebAPI + SignalR on `127.0.0.1:17000`.
- Docker `db` runs PostgreSQL in an internal Docker network.

## 1) DNS

Point `example.com` A record to your VPS public IP.

## 2) Install packages on VPS

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

Install Docker Engine + Docker Compose plugin (if not installed yet).

## 3) Upload source and prepare env

```bash
cd /opt
sudo mkdir -p mahjong-scoreboard
sudo chown -R $USER:$USER mahjong-scoreboard
cd mahjong-scoreboard
```

Place this repository under `/opt/mahjong-scoreboard`, then:

```bash
cp .env.example .env
```

Edit `.env`:

```dotenv
POSTGRES_DB=mahjong_scoreboard_db
POSTGRES_USER=mahjong
POSTGRES_PASSWORD=<strong-password>
API_BASE_URL=https://example.com
```

## 4) Start containers

```bash
docker compose build
docker compose up -d
docker compose ps
```

Expected:
- `api` bound only to `127.0.0.1:17000`
- `client` bound only to `127.0.0.1:17001`

## 5) Configure host Nginx

For first deployment, use bootstrap config first:

```bash
sudo cp deploy/nginx/example.com.bootstrap.conf /etc/nginx/sites-available/example.com
sudo ln -s /etc/nginx/sites-available/example.com /etc/nginx/sites-enabled/example.com
sudo nginx -t
sudo systemctl reload nginx
```

## 6) Issue TLS certificate

```bash
sudo certbot --nginx -d example.com
```

## 7) Switch to production Nginx config

After certificate issuance, replace with production config:

```bash
sudo cp deploy/nginx/example.com.conf /etc/nginx/sites-available/example.com
sudo nginx -t
sudo systemctl reload nginx
```

## 8) Verify

```bash
curl -I https://example.com
curl -I https://example.com/api/users
```

Then open:

`https://example.com`

## 9) Update flow

```bash
cd /opt/mahjong-scoreboard
docker compose build
docker compose up -d
```

## Notes

- In production, Flutter build uses `API_BASE_URL` from `.env`.
- SignalR is routed through host Nginx at `/hubs/room`.
- ASP.NET app applies DB migrations automatically on startup (`db.Database.Migrate()` in `Program.cs`).

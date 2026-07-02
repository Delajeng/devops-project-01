# Project 1 — Containerise and Ship a Web App
**Difficulty:** ⭐ Beginner | **Time:** 3–4 hrs | **Leads into:** Project 2 (IaC)

---

## What you're building

A simple web app (your choice of language — Node.js, Python Flask, or plain nginx) packaged into a Docker image, pushed to a container registry, and automatically rebuilt on every `git push` via GitHub Actions. This is the foundation every other project builds on — if you can containerise and ship an app, everything else in this roadmap is just orchestrating containers at scale.

## What you'll learn

- Writing a `Dockerfile` from scratch and understanding each instruction
- Building, tagging, and pushing images to a registry
- Multi-stage builds (smaller, more secure images)
- GitHub Actions basics: triggers, jobs, steps, secrets
- Container registries: Docker Hub vs GitHub Container Registry (ghcr.io)

## Architecture

```
Developer laptop
      │
      │ git push
      ▼
GitHub repository
      │
      │ triggers
      ▼
GitHub Actions (free, cloud-hosted runner)
      ├─ checkout code
      ├─ docker build
      ├─ docker test (run container, hit health endpoint)
      └─ docker push → registry (Docker Hub or ghcr.io)
                              │
                              ▼
                    Image available to pull anywhere
                    (cloud VM, Kubernetes, laptop)
```

## Cloud vs. local

| Step | Cloud path | Local path |
|------|-----------|------------|
| Run the app | Any cloud VM | `docker run` on your laptop |
| CI pipeline | GitHub Actions (free) | `act` (runs Actions locally) |
| Registry | Docker Hub (free) or ghcr.io | Local registry (`docker run registry:2`) |

---

## Prerequisites

- Git installed and a GitHub account
- Docker Desktop installed (Windows/Mac) or Docker Engine (Linux)
- A text editor (VS Code recommended)
- A Docker Hub account (free) — https://hub.docker.com

---

## Step-by-step

### Step 1 — Create the GitHub repo

```bash
# On your laptop
mkdir devops-project-01
cd devops-project-01
git init
git checkout -b main
```

Create `.gitignore` immediately:

```
node_modules/
__pycache__/
*.pyc
.env
.DS_Store
```

### Step 2 — Write the app

Pick one. All three produce the same outcome for this project.

**Option A: Python Flask**

```bash
mkdir app
```

`app/app.py`:
```python
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "<h1>DevOps Project 1</h1><p>Containerised and shipped.</p>"

@app.route("/health")
def health():
    return jsonify({"status": "ok", "version": os.getenv("APP_VERSION", "dev")})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

`app/requirements.txt`:
```
flask==3.0.3
gunicorn==22.0.0
```

**Option B: Node.js**

`app/server.js`:
```javascript
const http = require("http");

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", version: process.env.APP_VERSION || "dev" }));
  } else {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end("<h1>DevOps Project 1</h1><p>Containerised and shipped.</p>");
  }
});

server.listen(8080, () => console.log("Server running on :8080"));
```

**Option C: Plain nginx (no code needed)**

```bash
mkdir app
echo "<h1>DevOps Project 1</h1><p>Containerised and shipped.</p>" > app/index.html
```

### Step 3 — Write the Dockerfile

**For Python Flask:**

```dockerfile
# ── Build stage ──────────────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM python:3.12-slim

# Create a non-root user — never run apps as root inside containers
RUN useradd --create-home appuser
WORKDIR /home/appuser/app

# Copy installed dependencies from builder
COPY --from=builder /install /usr/local

# Copy app code
COPY app/ .

# Switch to non-root user
USER appuser

EXPOSE 8080

# Use gunicorn (production WSGI server) not the Flask dev server
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
```

**For Node.js:**

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --only=production

FROM node:20-alpine
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /home/appuser/app
COPY --from=builder /app/node_modules ./node_modules
COPY app/ .
USER appuser
EXPOSE 8080
CMD ["node", "server.js"]
```

**For nginx:**

```dockerfile
FROM nginx:1.27-alpine
COPY app/index.html /usr/share/nginx/html/index.html
EXPOSE 80
```

### Step 4 — Build and test locally

```bash
# Build the image
docker build -t devops-project-01:dev .

# Run it
docker run -d -p 8080:8080 --name project01 devops-project-01:dev

# Test it
curl http://localhost:8080
curl http://localhost:8080/health

# Check the running container
docker ps
docker logs project01

# Clean up
docker stop project01
docker rm project01
```

### Step 5 — Write the GitHub Actions workflow

Create `.github/workflows/ci.yml`:

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  REGISTRY: docker.io
  IMAGE_NAME: ${{ secrets.DOCKERHUB_USERNAME }}/devops-project-01

jobs:
  build-test-push:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        # Only runs on push to main, not on pull requests
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build image (and push on main branch)
        uses: docker/build-push-action@v6
        with:
          context: .
          push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
          tags: |
            ${{ env.IMAGE_NAME }}:latest
            ${{ env.IMAGE_NAME }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Smoke test — run container and hit health endpoint
        run: |
          docker run -d -p 8080:8080 --name test-container ${{ env.IMAGE_NAME }}:${{ github.sha }}
          sleep 5
          curl --fail http://localhost:8080/health
          docker stop test-container
          docker rm test-container
```

### Step 6 — Add GitHub Actions secrets

In your GitHub repo: **Settings → Secrets and variables → Actions → New repository secret**

Add two secrets:
- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token (Docker Hub → Account Settings → Security → Access Tokens → Generate)

**Why a token instead of your password?** Tokens are scoped (read/write only, not account admin) and revocable. Never use your Docker Hub password as a CI secret.

### Step 7 — Commit and push

```bash
git add .
git status     # review what's staged
git commit -m "project-01: containerised app with GitHub Actions CI"
git push -u origin main
```

Go to your repo's **Actions** tab — watch the workflow run.

### Step 8 — Pull and run the published image from anywhere

Once the workflow passes:

```bash
# On any machine with Docker installed
docker pull YOUR-USERNAME/devops-project-01:latest
docker run -p 8080:8080 YOUR-USERNAME/devops-project-01:latest
```

Open `http://localhost:8080` — you're running the same image that came out of your CI pipeline.

---

## Using GitHub Container Registry instead of Docker Hub

ghcr.io is free for public images and doesn't require a separate account — it uses your GitHub token:

Change `env` in the workflow to:
```yaml
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ghcr.io/${{ github.repository_owner }}/devops-project-01
```

Change the login step to:
```yaml
- name: Log in to ghcr.io
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}   # automatically provided, no setup needed
```

## Local path — run Actions with `act`

`act` lets you run GitHub Actions workflows on your laptop without pushing to GitHub:

```bash
# Install act: https://nektosact.com/installation/index.html
# On Mac:
brew install act
# On Windows (winget):
winget install nektos.act

# Run the CI workflow locally (builds but doesn't push)
act push --secret DOCKERHUB_USERNAME=myuser --secret DOCKERHUB_TOKEN=mytoken
```

---

## Tutorials

- Docker official "Getting Started": https://docs.docker.com/get-started/
- Multi-stage builds explained: https://docs.docker.com/build/building/multi-stage/
- GitHub Actions quickstart: https://docs.github.com/en/actions/writing-workflows/quickstart
- docker/build-push-action reference: https://github.com/docker/build-push-action

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `docker: command not found` | Docker Desktop not installed or not running |
| `denied: requested access to the resource is denied` | Wrong Docker Hub credentials in secrets, or token scope too narrow |
| `curl: (7) Failed to connect` in smoke test | App not binding to `0.0.0.0` — check `host` in app config |
| Workflow runs on PRs but doesn't push | Correct — `if: github.event_name == 'push'` gate is working |

---

## Definition of done

- [ ] App runs locally via `docker run`
- [ ] `/health` endpoint returns `{"status": "ok"}`
- [ ] GitHub Actions workflow passes (green tick in Actions tab)
- [ ] Image visible on Docker Hub (or ghcr.io) with `:latest` and `:<sha>` tags
- [ ] Can pull and run the published image on a second machine

**Next:** [Project 2 — IaC: Provision a Server](../project-02-iac-provision-server/README.md)

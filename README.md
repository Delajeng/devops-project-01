# Project 1 — Containerise and Ship a Web App
---
## What was built

A simple web app  Python Flask, packaged into a Docker image, pushed to a container registry, 
and automatically rebuilt on every `git push` via GitHub Actions.

## What was learnt

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

---
## Prerequisites

- Git installed and a GitHub account
- Docker Desktop installed (Windows/Mac) or Docker Engine (Linux)
- A text editor (VS Code recommended)
- A Docker Hub account (free) — https://hub.docker.com

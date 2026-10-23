# Project 1 — Containerise and Ship a Web App

[![CI](https://github.com/Delajeng/devops-project-01/actions/workflows/ci.yml/badge.svg)](https://github.com/Delajeng/devops-project-01/actions/workflows/ci.yml)

A small Flask app in a multi-stage Docker image. GitHub Actions builds and smoke-tests it on every push and pull request, and pushes the tested image to Docker Hub from `main`.

**Full write-up:** https://delajeng.dev/projects/containerise-and-ship/

## Run locally

From PowerShell, with Docker Desktop running:

```powershell
docker build -t devops-project-01 .
docker run -d -p 8080:8080 --name devops-project-01 devops-project-01
Invoke-RestMethod http://localhost:8080/health   # status: ok, version: dev
docker rm -f devops-project-01
```

## CI secrets

| Secret               | Value |
| -------------------- | ----- |
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN`    | Docker Hub access token |

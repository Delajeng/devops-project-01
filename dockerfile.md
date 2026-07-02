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
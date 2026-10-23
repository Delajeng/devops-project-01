FROM python:3.12-slim AS builder

WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.12-slim

RUN useradd --create-home appuser
WORKDIR /home/appuser/app

COPY --from=builder /install /usr/local

COPY app/ .

# Version reported by /health. CI passes the commit SHA; local builds default to "dev".
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

USER appuser

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]

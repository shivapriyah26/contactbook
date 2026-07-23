# ---- Stage 1: build dependencies in an isolated layer ----
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build deps only where needed, then discard this whole layer later
RUN apt-get update && apt-get install -y --no-install-recommends gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# ---- Stage 2: slim runtime image, no compilers, no build tools ----
FROM python:3.12-slim

WORKDIR /app

# Run as non-root for security
RUN useradd --create-home appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY . .
RUN chown -R appuser:appuser /app

USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# Container-level health check (also used by ECS)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

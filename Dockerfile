# syntax=docker/dockerfile:1

# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /usr/src/app

# Install system dependencies needed by common Python packages
# (psycopg2, cryptography, uvloop/httptools, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    curl \
    git \
    libpq-dev \
    libffi-dev \
    libssl-dev \
    pkg-config \
 && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better layer caching
COPY requirements.txt .

# Upgrade packaging tooling and install deps
RUN python -m pip install --upgrade pip setuptools wheel && \
    python -m pip install --no-cache-dir -r requirements.txt

# Copy app code
COPY . .

# Create necessary directories (won't fail if they already exist)
RUN mkdir -p knowledge_base chroma_db static templates

# Environment setup
ENV PYTHONPATH=/usr/src/app \
    PYTHONUNBUFFERED=1

# Add entrypoint for runtime DB build
COPY entrypoint.sh /usr/src/app/
RUN chmod +x /usr/src/app/entrypoint.sh

# Expose the port you will actually serve on (keep consistent everywhere)
EXPOSE 80

# Healthcheck must probe the *same* port as the app
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost:80/api/health || exit 1

# Run app (goes through entrypoint.sh first)
ENTRYPOINT ["./entrypoint.sh"]
CMD ["uvicorn", "run:app", "--host", "0.0.0.0", "--port", "80"]
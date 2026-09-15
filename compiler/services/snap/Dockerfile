FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 SNAP_DATABASE=/app/data/snap.sqlite3
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --uid 10001 --create-home snap && mkdir /app/data && chown snap:snap /app/data
COPY snap_service ./snap_service
USER snap
EXPOSE 8000
CMD ["uvicorn", "snap_service.main:create_app", "--factory", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--no-access-log", "--no-proxy-headers"]

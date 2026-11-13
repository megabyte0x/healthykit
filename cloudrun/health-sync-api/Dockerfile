FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PORT=8080
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd --system --uid 10001 app
COPY app.py models.py main.py remote_mcp.py oauth_store.py official_storage.py ./
COPY backend ./backend
USER 10001
EXPOSE 8080
CMD ["sh","-c","exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080} --no-access-log"]

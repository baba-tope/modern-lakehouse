# Use a slim Python base image
FROM python:3.10-slim

WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY dashboard-api.py .

EXPOSE 8081

CMD ["uvicorn", "dashboard-api:app", "--host", "0.0.0.0", "--port", "8081"]
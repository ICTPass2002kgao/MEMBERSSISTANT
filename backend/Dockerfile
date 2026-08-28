FROM python:3.13-slim 
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED 1

RUN apt-get update && \
    apt-get install -y \
    git \
    cmake \
    build-essential \
    libgl1 \
    libx11-dev \
    libgtk-3-dev \
    python3-dev \
    poppler-utils \
    && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /app/

ENV PORT 8080

CMD sh -c "python manage.py migrate && python manage.py collectstatic --noinput && gunicorn memberssistant.wsgi --forwarded-allow-ips '*' --bind 0.0.0.0:$PORT --timeout 90"
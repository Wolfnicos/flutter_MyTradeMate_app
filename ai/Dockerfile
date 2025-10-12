FROM python:3.11-slim

RUN apt-get update && apt-get install -y git build-essential cmake && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY ai/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

# scripts și artifacts vor fi montate din host la runtime
CMD ["bash","-lc","python ai/scripts/export_onnx.py"]

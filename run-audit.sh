#!/usr/bin/env bash
set -euo pipefail

IMAGE=mytrademate-audit

docker build -t $IMAGE .
docker run --rm -v "$PWD":/app $IMAGE "$@"



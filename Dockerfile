# Audit container: Flutter stable toolchain to run CLI scripts reliably
# Usage:
#   docker build -t mytrademate-audit .
#   docker run --rm -v "$PWD":/app mytrademate-audit

FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

# Copy only pubspec first for better layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get || true

# Copy the rest of the project
COPY . .

# Ensure dependencies are fetched inside container
RUN flutter pub get

# Default command runs the comprehensive audit runner
CMD ["bash", "-lc", "flutter pub run tool/run_comprehensive_audit.dart"]



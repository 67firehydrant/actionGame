#!/usr/bin/env bash
set -Eeuo pipefail

PORT="${PORT:-3000}"
HEALTH_PATH="${HEALTH_PATH:-/}"
DURATION_MINUTES="${DURATION_MINUTES:-330}"
START_COMMAND="${START_COMMAND:-}"
DEFAULT_START_COMMAND="${DEFAULT_START_COMMAND:-npm run start}"
APP_LOG="${APP_LOG:-next-server.log}"
CLOUDFLARED_LOG="${CLOUDFLARED_LOG:-cloudflared.log}"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-}"

if [ -z "$CLOUDFLARED_BIN" ]; then
  if [ -x "./node_modules/.bin/cloudflared" ]; then
    CLOUDFLARED_BIN="./node_modules/.bin/cloudflared"
  elif [ -x "./node_modules/@farthershore/cloudflared-linux-x64/bin/cloudflared" ]; then
    CLOUDFLARED_BIN="./node_modules/@farthershore/cloudflared-linux-x64/bin/cloudflared"
  else
    CLOUDFLARED_BIN="cloudflared"
  fi
fi

if ! [[ "$DURATION_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "::error::duration_minutes must be a number. Got: $DURATION_MINUTES"
  exit 1
fi

if [ "$DURATION_MINUTES" -gt 350 ]; then
  echo "::warning::duration_minutes=$DURATION_MINUTES is above the safe GitHub-hosted runner window. Capping to 350 minutes."
  DURATION_MINUTES=350
fi

if [ -z "$START_COMMAND" ]; then
  START_COMMAND="$DEFAULT_START_COMMAND"
fi

if [[ "$HEALTH_PATH" != /* ]]; then
  HEALTH_PATH="/${HEALTH_PATH}"
fi

LOCAL_URL="http://127.0.0.1:${PORT}${HEALTH_PATH}"
DURATION_SECONDS=$((DURATION_MINUTES * 60))
STARTED_AT=$(date +%s)

cleanup() {
  set +e
  echo "Stopping background processes..."
  if [ -n "${TAIL_PID:-}" ]; then kill "$TAIL_PID" 2>/dev/null || true; fi
  if [ -n "${CLOUDFLARED_PID:-}" ]; then kill "$CLOUDFLARED_PID" 2>/dev/null || true; fi
  if [ -n "${APP_PID:-}" ]; then kill "$APP_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT INT TERM

: > "$APP_LOG"
: > "$CLOUDFLARED_LOG"

echo "Starting app with: PORT=$PORT HOSTNAME=0.0.0.0 $START_COMMAND"
PORT="$PORT" HOSTNAME="0.0.0.0" bash -lc "$START_COMMAND" > "$APP_LOG" 2>&1 &
APP_PID=$!

echo "Waiting for local app health at ${LOCAL_URL}..."
for i in {1..90}; do
  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "::error::Next.js server exited before becoming healthy."
    tail -n 200 "$APP_LOG" || true
    exit 1
  fi

  if curl -fsS --max-time 5 "$LOCAL_URL" >/dev/null; then
    echo "Local app is healthy."
    break
  fi

  if [ "$i" -eq 90 ]; then
    echo "::error::Timed out waiting for local app health at ${LOCAL_URL}."
    tail -n 200 "$APP_LOG" || true
    exit 1
  fi

  sleep 2
done

echo "Starting TryCloudflare tunnel..."
"$CLOUDFLARED_BIN" tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate > "$CLOUDFLARED_LOG" 2>&1 &
CLOUDFLARED_PID=$!

PUBLIC_URL=""
for i in {1..120}; do
  if ! kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
    echo "::error::cloudflared exited before publishing a TryCloudflare URL."
    tail -n 200 "$CLOUDFLARED_LOG" || true
    exit 1
  fi

  PUBLIC_URL="$(grep -Eo 'https://[-a-zA-Z0-9]+\.trycloudflare\.com' "$CLOUDFLARED_LOG" | head -n 1 || true)"
  if [ -n "$PUBLIC_URL" ]; then
    break
  fi
  sleep 1
done

if [ -z "$PUBLIC_URL" ]; then
  echo "::error::Could not find a TryCloudflare URL in cloudflared logs."
  tail -n 200 "$CLOUDFLARED_LOG" || true
  exit 1
fi

{
  echo "## Next.js TryCloudflare test server"
  echo ""
  echo "Public URL: ${PUBLIC_URL}"
  echo "Local health check: ${LOCAL_URL}"
  echo "Planned runtime: ${DURATION_MINUTES} minutes"
  echo ""
  echo "This URL is temporary and only works while this GitHub Actions job is running."
} >> "$GITHUB_STEP_SUMMARY"

echo "TryCloudflare URL: ${PUBLIC_URL}"
echo "Streaming logs. The job will monitor process exits and health-check failures."

tail -n +1 -F "$APP_LOG" "$CLOUDFLARED_LOG" &
TAIL_PID=$!

failures=0
last_heartbeat=0
while true; do
  now=$(date +%s)
  elapsed=$((now - STARTED_AT))

  if [ "$elapsed" -ge "$DURATION_SECONDS" ]; then
    echo "Requested duration reached (${DURATION_MINUTES} minutes). Stopping cleanly."
    exit 0
  fi

  if ! kill -0 "$APP_PID" 2>/dev/null; then
    echo "::error::Next.js server process stopped unexpectedly."
    tail -n 200 "$APP_LOG" || true
    exit 1
  fi

  if ! kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
    echo "::error::cloudflared tunnel process stopped unexpectedly."
    tail -n 200 "$CLOUDFLARED_LOG" || true
    exit 1
  fi

  if curl -fsS --max-time 10 "$LOCAL_URL" >/dev/null; then
    failures=0
  else
    failures=$((failures + 1))
    echo "::warning::Health check failed (${failures}/3): ${LOCAL_URL}"
    if [ "$failures" -ge 3 ]; then
      echo "::error::Health check failed 3 times in a row."
      tail -n 200 "$APP_LOG" || true
      exit 1
    fi
  fi

  if [ $((now - last_heartbeat)) -ge 60 ]; then
    remaining=$((DURATION_SECONDS - elapsed))
    echo "Heartbeat: ${PUBLIC_URL} is still being monitored. Remaining seconds: ${remaining}."
    last_heartbeat=$now
  fi

  sleep 15
done

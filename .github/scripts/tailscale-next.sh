#!/usr/bin/env bash
set -Eeuo pipefail

PORT="${PORT:-3000}"
HEALTH_PATH="${HEALTH_PATH:-/}"
DURATION_MINUTES="${DURATION_MINUTES:-330}"
START_COMMAND="${START_COMMAND:-}"
DEFAULT_START_COMMAND="${DEFAULT_START_COMMAND:-npm run start}"
EXPOSE_MODE="${EXPOSE_MODE:-serve}" # serve = private tailnet, funnel = public internet
APP_LOG="${APP_LOG:-next-server.log}"

if ! command -v tailscale >/dev/null 2>&1; then
  echo "::error::tailscale command not found. Run tailscale/github-action before this script."
  exit 1
fi

if ! [[ "$DURATION_MINUTES" =~ ^[0-9]+$ ]]; then
  echo "::error::duration_minutes must be a number. Got: $DURATION_MINUTES"
  exit 1
fi

if [ "$DURATION_MINUTES" -gt 350 ]; then
  echo "::warning::duration_minutes=$DURATION_MINUTES is above the safe GitHub-hosted runner window. Capping to 350 minutes."
  DURATION_MINUTES=350
fi

if [[ "$HEALTH_PATH" != /* ]]; then
  HEALTH_PATH="/${HEALTH_PATH}"
fi

if [ -z "$START_COMMAND" ]; then
  START_COMMAND="$DEFAULT_START_COMMAND"
fi

LOCAL_URL="http://127.0.0.1:${PORT}${HEALTH_PATH}"
DURATION_SECONDS=$((DURATION_MINUTES * 60))
STARTED_AT=$(date +%s)

cleanup() {
  set +e
  echo "Stopping background processes..."
  if [ -n "${TAIL_PID:-}" ]; then kill "$TAIL_PID" 2>/dev/null || true; fi
  if [ -n "${APP_PID:-}" ]; then kill "$APP_PID" 2>/dev/null || true; fi
  if [ "${EXPOSE_MODE}" = "funnel" ]; then
    tailscale funnel reset >/dev/null 2>&1 || true
  else
    tailscale serve reset >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

: > "$APP_LOG"

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

DNS_NAME="$(tailscale status --json | node -e "let d=''; process.stdin.on('data', c=>d+=c); process.stdin.on('end',()=>{const j=JSON.parse(d); console.log((j.Self&&j.Self.DNSName||'').replace(/\\.$/,''));})")"
TS_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

if [ -z "$DNS_NAME" ]; then
  echo "::warning::Could not read MagicDNS hostname from Tailscale status. Falling back to Tailscale IP."
  ACCESS_URL="http://${TS_IP}:${PORT}"
else
  ACCESS_URL="https://${DNS_NAME}"
fi

case "$EXPOSE_MODE" in
  serve)
    echo "Starting Tailscale Serve for tailnet-only access..."
    tailscale serve reset >/dev/null 2>&1 || true
    tailscale serve --bg "$PORT"
    ACCESS_SCOPE="Tailnet only"
    ;;
  funnel)
    echo "Starting Tailscale Funnel for public internet access..."
    tailscale funnel reset >/dev/null 2>&1 || true
    tailscale funnel --bg "$PORT"
    ACCESS_SCOPE="Public internet via Tailscale Funnel"
    ;;
  *)
    echo "::error::EXPOSE_MODE must be 'serve' or 'funnel'. Got: $EXPOSE_MODE"
    exit 1
    ;;
esac

{
  echo "## Next.js Tailscale test server"
  echo ""
  echo "Access mode: ${ACCESS_SCOPE}"
  echo "URL: ${ACCESS_URL}"
  echo "Local health check: ${LOCAL_URL}"
  echo "Planned runtime: ${DURATION_MINUTES} minutes"
  echo ""
  if [ "$EXPOSE_MODE" = "serve" ]; then
    echo "This URL only works for devices/users inside your Tailscale tailnet."
  else
    echo "This URL is public while Funnel is enabled and this GitHub Actions job is running."
  fi
  echo ""
  echo "### Tailscale serve/funnel status"
  echo '```'
  tailscale serve status 2>/dev/null || tailscale funnel status 2>/dev/null || true
  echo '```'
} >> "$GITHUB_STEP_SUMMARY"

echo "Tailscale URL: ${ACCESS_URL}"
echo "Access mode: ${ACCESS_SCOPE}"
echo "Streaming app logs. The job will monitor process exits and health-check failures."

tail -n +1 -F "$APP_LOG" &
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

  if ! tailscale status >/dev/null 2>&1; then
    echo "::error::Tailscale status failed."
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
    echo "Heartbeat: ${ACCESS_URL} is still being monitored. Remaining seconds: ${remaining}."
    last_heartbeat=$now
  fi

  sleep 15
done

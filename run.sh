#!/usr/bin/env bash

set -Eeuo pipefail

APP_PORT="${APP_PORT:-4000}"
MIX_ENV="${MIX_ENV:-dev}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"

LOG_PREFIX="[start.sh]"

log() {
  echo "${LOG_PREFIX} $*"
}

die() {
  echo "${LOG_PREFIX} ERROR: $*" >&2
  exit 1
}

prompt_ync() {
  local message="$1"
  local answer

  while true; do
    read -r -p "${message} [y/n/c]: " answer

    case "${answer,,}" in
      y | yes)
        return 0
        ;;
      n | no)
        return 1
        ;;
      c | cancel)
        log "Cancelled."
        exit 130
        ;;
      *)
        echo "Please answer y, n, or c."
        ;;
    esac
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

docker_compose() {
  if [[ -f "${COMPOSE_FILE}" ]]; then
    docker compose -f "${COMPOSE_FILE}" "$@"
  else
    docker compose "$@"
  fi
}

port_pids() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -tiTCP:"${APP_PORT}" -sTCP:LISTEN 2>/dev/null || true
  else
    return 0
  fi
}

show_port_usage() {
  log "Port ${APP_PORT} is currently in use."

  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"${APP_PORT}" -sTCP:LISTEN || true
  elif command -v ss >/dev/null 2>&1; then
    ss -ltnp "sport = :${APP_PORT}" || true
  else
    log "Install lsof or ss to see which process is using the port."
  fi
}

stop_pids() {
  local pids="$1"

  if [[ -z "${pids}" ]]; then
    return 0
  fi

  log "Stopping process(es): ${pids}"
  kill ${pids} 2>/dev/null || true

  for _ in {1..20}; do
    sleep 0.25

    local still_running=""
    for pid in ${pids}; do
      if kill -0 "${pid}" 2>/dev/null; then
        still_running="${still_running} ${pid}"
      fi
    done

    if [[ -z "${still_running}" ]]; then
      log "Stopped."
      return 0
    fi
  done

  log "Process did not stop gracefully. Force killing:${pids}"
  kill -9 ${pids} 2>/dev/null || true
}

check_port() {
  local pids
  pids="$(port_pids)"

  if [[ -z "${pids}" ]]; then
    log "Port ${APP_PORT} is free."
    return 0
  fi

  show_port_usage

  if prompt_ync "Something is already running on port ${APP_PORT}. Restart it?"; then
    stop_pids "${pids}"
  else
    log "Leaving existing process running."
    log "App may already be available at: http://localhost:${APP_PORT}"
    exit 0
  fi
}

start_docker() {
  require_command docker

  log "Starting Docker Compose services..."

  if docker compose up --help | grep -q -- "--wait"; then
    docker_compose up -d --wait
  else
    docker_compose up -d
  fi

  log "Docker Compose services started."
}

ensure_deps() {
  require_command mix

  log "Fetching Elixir dependencies..."
  MIX_ENV="${MIX_ENV}" mix deps.get
}

check_migrations() {
  log "Checking Ecto migrations..."

  local output
  local status

  set +e
  output="$(MIX_ENV="${MIX_ENV}" mix ecto.migrations 2>&1)"
  status=$?
  set -e

  echo "${output}"

  if [[ "${status}" -ne 0 ]]; then
    log "Could not check migrations."

    if echo "${output}" | grep -Eiq "database.*does not exist|unknown database|does not exist"; then
      if prompt_ync "Database appears to be missing. Run mix ecto.create?"; then
        MIX_ENV="${MIX_ENV}" mix ecto.create
      else
        log "Continuing without creating the database."
        return 0
      fi

      set +e
      output="$(MIX_ENV="${MIX_ENV}" mix ecto.migrations 2>&1)"
      status=$?
      set -e

      echo "${output}"

      if [[ "${status}" -ne 0 ]]; then
        die "Migration check still failed."
      fi
    else
      die "Migration check failed."
    fi
  fi

  if echo "${output}" | grep -Eiq '(^|[[:space:]])down([[:space:]]|$)'; then
    log "Pending migrations detected."

    if prompt_ync "Run mix ecto.migrate?"; then
      MIX_ENV="${MIX_ENV}" mix ecto.migrate
    else
      log "Continuing without running migrations."
    fi
  else
    log "No pending migrations."
  fi
}

start_phoenix() {
  log "Starting Phoenix on http://localhost:${APP_PORT}"
  log "MIX_ENV=${MIX_ENV}"

  export PORT="${APP_PORT}"
  export MIX_ENV="${MIX_ENV}"

  exec mix phx.server
}

main() {
  log "Starting local Phoenix app..."

  check_port
  start_docker
  ensure_deps
  check_migrations
  start_phoenix
}

main "$@"

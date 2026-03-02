#!/usr/bin/env bash
# =============================================================================
# stop-local.sh — Stop locally running Shopizer services
# =============================================================================
# Usage:
#   ./stop-local.sh [OPTIONS]
#
# Options:
#   --force    Force kill processes listening on ports 8080/3306 (use if containers stuck)
#   --help     Show this help message
#
# This script stops:
#   - Shopizer Docker container (if running as docker)
#   - Shopizer Java process (if running as jar or local)
#   - MySQL Docker container
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Defaults ─────────────────────────────────────────────────────────────────
FORCE=false
MYSQL_CONTAINER="shopizer-mysql"
APP_CONTAINER="shopizer-app"
APP_PORT=8080
MYSQL_PORT=3306

# ─── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    --help|-h) 
      sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
      exit 0
      ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Shopizer — Local Stopper           ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# Stop Docker containers if docker is available
if command -v docker &>/dev/null; then
  # Stop app container if running
  if docker ps --filter "name=$APP_CONTAINER" --format "{{.Names}}" | grep -q "^${APP_CONTAINER}$"; then
    info "Stopping Docker container: $APP_CONTAINER"
    docker stop "$APP_CONTAINER" 2>/dev/null || true
    success "Container stopped: $APP_CONTAINER"
  fi

  # Remove app container if exists
  if docker ps -a --filter "name=$APP_CONTAINER" --format "{{.Names}}" | grep -q "^${APP_CONTAINER}$"; then
    info "Removing Docker container: $APP_CONTAINER"
    docker rm -f "$APP_CONTAINER" 2>/dev/null || true
    success "Container removed: $APP_CONTAINER"
  fi

  # Stop MySQL container if running
  if docker ps --filter "name=$MYSQL_CONTAINER" --format "{{.Names}}" | grep -q "^${MYSQL_CONTAINER}$"; then
    info "Stopping MySQL container: $MYSQL_CONTAINER"
    docker stop "$MYSQL_CONTAINER" 2>/dev/null || true
    success "MySQL container stopped: $MYSQL_CONTAINER"
  fi

  # Remove MySQL container if exists
  if docker ps -a --filter "name=$MYSQL_CONTAINER" --format "{{.Names}}" | grep -q "^${MYSQL_CONTAINER}$"; then
    info "Removing MySQL container: $MYSQL_CONTAINER"
    docker rm -f "$MYSQL_CONTAINER" 2>/dev/null || true
    success "MySQL container removed: $MYSQL_CONTAINER"
  fi
else
  warn "Docker not available — skipping container cleanup"
fi

# Kill Java processes if running (from jar or local mode)
if pgrep -f shopizer.jar >/dev/null 2>&1; then
  info "Killing Shopizer Java process(es)..."
  pkill -f shopizer.jar || true
  success "Shopizer Java process terminated"
fi

# Force kill processes on ports if --force flag is used
if [[ "$FORCE" == "true" ]]; then
  info "Force mode: Checking for processes on ports $APP_PORT and $MYSQL_PORT"
  
  # Kill on app port (macOS)
  if lsof -Pi :$APP_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    warn "Found process on port $APP_PORT — force killing..."
    lsof -Pi :$APP_PORT -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
    success "Port $APP_PORT freed"
  fi

  # Kill on MySQL port (macOS)
  if lsof -Pi :$MYSQL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    warn "Found process on port $MYSQL_PORT — force killing..."
    lsof -Pi :$MYSQL_PORT -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
    success "Port $MYSQL_PORT freed"
  fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
success "Shopizer services stopped successfully"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  You can now run: ${YELLOW}./run-local.sh${NC} to start fresh"
echo ""

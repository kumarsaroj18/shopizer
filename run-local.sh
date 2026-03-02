#!/usr/bin/env bash
# =============================================================================
# run-local.sh — Download and run Shopizer locally from GitHub CI artifacts
# =============================================================================
# Usage:
#   ./run-local.sh [OPTIONS]
#
# Options:
#   --mode docker   (default) Pull latest Docker image from ghcr.io and run
#   --mode jar      Download latest shopizer.jar via gh CLI and run with java
#   --mode local    Build from source locally and run (no CI artifacts needed)
#   --owner <name>  GitHub owner/org name (defaults to git remote origin owner)
#   --tag <tag>     Docker image tag to pull (default: latest)
#   --help          Show this help message
#
# Prerequisites:
#   docker         Required for all modes (MySQL is always run as a container)
#   java 11+       Required only for --mode jar / --mode local
#   maven (mvnw)   Required only for --mode local
#   gh             Required only for --mode jar (GitHub CLI: https://cli.github.com)
# =============================================================================

set -euo pipefail

# ─── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m';  GREEN='\033[0;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;36m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Defaults ─────────────────────────────────────────────────────────────────
MODE="docker"
TAG="latest"
APP_PORT=8080
MYSQL_PORT=3306
MYSQL_DB=SALESMANAGER
MYSQL_USER=app_user
MYSQL_PASSWORD=app_password
MYSQL_ROOT_PASSWORD=root
MYSQL_CONTAINER=shopizer-mysql
APP_CONTAINER=shopizer-app
OWNER=""

usage() {
  sed -n '/^# Usage/,/^# ====/p' "$0" | grep -v '^# ====' | sed 's/^# //'
  exit 0
}

# ─── Parse arguments ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)   MODE="$2";  shift 2 ;;
    --owner)  OWNER="$2"; shift 2 ;;
    --tag)    TAG="$2";   shift 2 ;;
    --help|-h) usage ;;
    *) error "Unknown option: $1"; usage ;;
  esac
done

if [[ "$MODE" != "docker" && "$MODE" != "jar" && "$MODE" != "local" ]]; then
  error "--mode must be 'docker', 'jar', or 'local'"; exit 1
fi

# ─── Detect GitHub owner/repo from git remote ─────────────────────────────────
detect_owner_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || true)

  if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
    OWNER="${BASH_REMATCH[1]}"
    REPO="${BASH_REMATCH[2]}"
  else
    OWNER=""
    REPO="shopizer"
  fi
}

if [[ -z "$OWNER" ]]; then
  detect_owner_repo
  if [[ -z "$OWNER" ]]; then
    error "Could not detect GitHub owner from git remote. Pass --owner <name>."
    exit 1
  fi
else
  # Owner supplied manually — still detect repo name
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  REPO=$(echo "$REMOTE_URL" | sed 's|.*github\.com[:/][^/]*/||;s|\.git$||')
  REPO="${REPO:-shopizer}"
fi

IMAGE="ghcr.io/${OWNER}/shopizer:${TAG}"

# ─── Check prerequisites ──────────────────────────────────────────────────────
check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    error "Required tool not found: $1. $2"
    exit 1
  fi
}

info "Checking prerequisites..."
check_cmd docker "Install Docker: https://docs.docker.com/get-docker/"
if [[ "$MODE" == "jar" ]]; then
  check_cmd java "Install Java 11+: https://adoptium.net/"
  check_cmd gh   "Install GitHub CLI: https://cli.github.com/"
fi
if [[ "$MODE" == "local" ]]; then
  check_cmd java "Install Java 11+: https://adoptium.net/"
fi
success "All prerequisites satisfied"

# ─── Cleanup helper ───────────────────────────────────────────────────────────
cleanup_containers() {
  info "Stopping and removing containers..."
  docker rm -f "$MYSQL_CONTAINER" 2>/dev/null || true
  docker rm -f "$APP_CONTAINER"   2>/dev/null || true
  success "Cleanup done."
}

trap '
  echo ""
  warn "Interrupt received — cleaning up..."
  cleanup_containers
' INT TERM

# ─── Start MySQL ──────────────────────────────────────────────────────────────
start_mysql() {
  info "Starting MySQL 8.0 container..."

  docker rm -f "$MYSQL_CONTAINER" 2>/dev/null || true

  docker run -d \
    --name "$MYSQL_CONTAINER" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DB" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    -p "${MYSQL_PORT}:3306" \
    mysql:8.0 \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci \
    --default-authentication-plugin=mysql_native_password \
    >/dev/null

  info "Waiting for MySQL to be ready..."
  local retries=30
  until docker exec "$MYSQL_CONTAINER" mysqladmin ping -h 127.0.0.1 -u root --password="$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do
    retries=$((retries - 1))
    if [[ $retries -le 0 ]]; then
      error "MySQL did not become ready in time."
      docker logs "$MYSQL_CONTAINER"
      cleanup_containers
      exit 1
    fi
    sleep 2
  done
  success "MySQL is ready on port $MYSQL_PORT"
}

# ─── GHCR Authentication ──────────────────────────────────────────────────────
ghcr_login() {
  info "Authenticating with GitHub Container Registry (ghcr.io)..."

  # Try gh CLI token first (seamless if already logged in)
  if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
    gh auth token | docker login ghcr.io -u "$OWNER" --password-stdin 2>/dev/null \
      && { success "Logged in to ghcr.io via GitHub CLI token"; return; }
  fi

  # Fall back to interactive password prompt
  warn "Could not authenticate automatically. Please enter your GitHub credentials."
  warn "Use a Personal Access Token (PAT) with 'read:packages' scope as the password."
  warn "Create one at: https://github.com/settings/tokens/new?scopes=read:packages"
  docker login ghcr.io -u "$OWNER"
}

# ─── MODE: docker ─────────────────────────────────────────────────────────────
run_docker_mode() {
  info "Mode: docker — pulling $IMAGE"

  # Check if already logged in, login if not
  if ! docker pull "$IMAGE" --quiet 2>/dev/null; then
    ghcr_login
    if ! docker pull "$IMAGE"; then
      echo ""
      error "Could not pull $IMAGE"
      error "This usually means either:"
      error "  1. The GitHub Actions CI pipeline hasn't run yet on main/master."
      error "     → Push the .github/workflows/ci.yml to your repo and let it complete."
      error "  2. The package is private and auth failed."
      error "     → Make it public: https://github.com/users/${OWNER}/packages"
      error "  3. Or use --mode local to build and run from source instead:"
      error "     → ./run-local.sh --mode local"
      exit 1
    fi
  fi
  success "Image ready: $IMAGE"

  start_mysql

  info "Starting Shopizer application container..."
  docker rm -f "$APP_CONTAINER" 2>/dev/null || true

  docker run -d \
    --name "$APP_CONTAINER" \
    --link "$MYSQL_CONTAINER":mysql \
    -e SPRING_PROFILES_ACTIVE=mysql \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://mysql:3306/${MYSQL_DB}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
    -e SPRING_DATASOURCE_USERNAME="$MYSQL_USER" \
    -e SPRING_DATASOURCE_PASSWORD="$MYSQL_PASSWORD" \
    -p "${APP_PORT}:8080" \
    "$IMAGE"

  print_startup_info "docker logs -f $APP_CONTAINER" "docker rm -f ${APP_CONTAINER} ${MYSQL_CONTAINER}"
}

# ─── MODE: jar ────────────────────────────────────────────────────────────────
run_jar_mode() {
  info "Mode: jar — downloading latest shopizer.jar from GitHub Actions"

  if ! gh auth status &>/dev/null; then
    error "Not logged in to GitHub CLI. Run: gh auth login"
    exit 1
  fi

  JAR_DIR="/tmp/shopizer-run"
  mkdir -p "$JAR_DIR"

  info "Fetching latest successful workflow run from ${OWNER}/${REPO}..."

  RUN_ID=$(gh run list \
    --repo "${OWNER}/${REPO}" \
    --workflow ci.yml \
    --status success \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId')

  if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
    error "No successful CI workflow runs found for ${OWNER}/${REPO}."
    error "Make sure the CI pipeline has run at least once successfully on main/master."
    error "Or use --mode local to build from source: ./run-local.sh --mode local"
    exit 1
  fi

  info "Found successful run ID: $RUN_ID. Downloading artifact..."

  gh run download "$RUN_ID" \
    --repo "${OWNER}/${REPO}" \
    --pattern "shopizer-jar-*" \
    --dir "$JAR_DIR"

  DOWNLOADED_JAR=$(find "$JAR_DIR" -name "shopizer.jar" | head -1)
  if [[ -z "$DOWNLOADED_JAR" ]]; then
    error "Could not find shopizer.jar in downloaded artifacts."
    exit 1
  fi

  success "Downloaded: $DOWNLOADED_JAR"

  start_mysql

  info "Starting Shopizer application (java -jar)..."
  java \
    -jar "$DOWNLOADED_JAR" \
    --spring.profiles.active=mysql \
    "--spring.datasource.url=jdbc:mysql://127.0.0.1:${MYSQL_PORT}/${MYSQL_DB}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
    "--spring.datasource.username=${MYSQL_USER}" \
    "--spring.datasource.password=${MYSQL_PASSWORD}" \
    "--server.port=${APP_PORT}" &

  APP_PID=$!
  print_startup_info "kill $APP_PID" "docker rm -f ${MYSQL_CONTAINER}"
  wait "$APP_PID"
}

# ─── MODE: local ──────────────────────────────────────────────────────────────
run_local_mode() {
  info "Mode: local — building from source and running"
  warn "This will run a full Maven build. It may take a few minutes on first run."

  # Determine script location (project root)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  info "Building fat JAR (skipping tests)..."
  (cd "$SCRIPT_DIR" && ./mvnw package -DskipTests -pl sm-shop -am \
    --batch-mode)

  JAR_PATH="$SCRIPT_DIR/sm-shop/target/shopizer.jar"
  if [[ ! -f "$JAR_PATH" ]]; then
    error "Build failed — $JAR_PATH not found."
    exit 1
  fi
  success "Build complete: $JAR_PATH"

  start_mysql

  info "Starting Shopizer application (java -jar)..."
  java \
    -jar "$JAR_PATH" \
    --spring.profiles.active=mysql \
    "--spring.datasource.url=jdbc:mysql://127.0.0.1:${MYSQL_PORT}/${MYSQL_DB}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
    "--spring.datasource.username=${MYSQL_USER}" \
    "--spring.datasource.password=${MYSQL_PASSWORD}" \
    "--server.port=${APP_PORT}" &

  APP_PID=$!
  print_startup_info "kill $APP_PID" "docker rm -f ${MYSQL_CONTAINER}"
  wait "$APP_PID"
}

# ─── Print startup banner ─────────────────────────────────────────────────────
print_startup_info() {
  local stop_app="$1"
  local stop_mysql="$2"
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Shopizer is starting up!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  🌐  Application URL : ${BLUE}http://localhost:${APP_PORT}${NC}"
  echo -e "  📋  Swagger UI      : ${BLUE}http://localhost:${APP_PORT}/swagger-ui.html${NC}"
  echo -e "  ❤️   Health Check    : ${BLUE}http://localhost:${APP_PORT}/actuator/health${NC}"
  echo -e "  🗄️   MySQL Port      : ${BLUE}localhost:${MYSQL_PORT}${NC}  (db: ${MYSQL_DB})"
  echo ""
  echo -e "  🔑  Admin Login (auto-created on first startup):"
  echo -e "      Username: ${YELLOW}admin@shopizer.com${NC}"
  echo -e "      Password: ${YELLOW}password${NC}"
  echo ""
  echo -e "  ℹ️   The app may take 30–60 seconds to fully initialize."
  echo ""
  echo -e "  To stop the app  : ${YELLOW}${stop_app}${NC}"
  echo -e "  To stop MySQL    : ${YELLOW}${stop_mysql}${NC}"
  echo -e "  Or press         : ${YELLOW}Ctrl+C${NC} (cleans up automatically)"
  echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       Shopizer — Local Runner            ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
info "Repository : ${OWNER}/${REPO}"
info "Mode       : ${MODE}"
[[ "$MODE" == "docker" ]] && info "Image      : ${IMAGE}"
echo ""

case "$MODE" in
  docker) run_docker_mode ;;
  jar)    run_jar_mode ;;
  local)  run_local_mode ;;
esac

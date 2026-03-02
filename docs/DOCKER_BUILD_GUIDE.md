# Shopizer Docker Build Guide

This directory contains two Dockerfiles for building Shopizer Docker images:

## 1. **Dockerfile.local** - Local Build (Maven)

Builds the entire Shopizer application locally using Maven in a multi-stage build.

### Prerequisites
- Docker installed
- At least 4GB free disk space (for Maven build)

### Build Command
```bash
# Run from the shopizer root directory
cd shopizer

# Step 1: Build the project with Maven
./mvnw clean install -DskipTests

# Step 2: Build the Docker image
docker build -f Dockerfile.local -t shopizer:local .

# Run the container
docker run -p 8080:8080 shopizer:local
```

### Pros ✅
- No external dependencies (fully self-contained build)
- Works offline after dependencies are cached
- Full control over build process

### Cons ❌
- Longer build time (10-15 minutes)
- Larger intermediate images
- Requires more disk space during build

---

## 2. **Dockerfile.ci** - GitHub Actions CI Artifact

Downloads the pre-built JAR from GitHub Actions CI workflow and creates a minimal runtime image.

### Prerequisites
- Docker installed
- `gh` CLI installed and authenticated
- GitHub Actions workflow (`ci.yml`) has completed successfully
- `GITHUB_TOKEN` environment variable set (for private repositories)

### Setup `gh` CLI
```bash
# Install gh CLI (if not installed)
# macOS
brew install gh

# Linux (Ubuntu/Debian)
sudo apt-get install gh

# Authenticate
gh auth login
```

### Build Commands

**Option 1: Using the helper script (recommended)**
```bash
cd shopizer
chmod +x build-image-from-ci.sh

# Build with your GitHub details
./build-image-from-ci.sh your-github-username shopizer-repo main shopizer:ci-latest

# Examples:
./build-image-from-ci.sh john-doe shopizer-repo main shopizer:v1.0
./build-image-from-ci.sh myorg my-shopizer develop shopizer:latest
```

**Option 2: Manual Docker build**
```bash
cd shopizer

docker build \
  -f Dockerfile.ci \
  -t shopizer:ci-latest \
  --build-arg GITHUB_OWNER=your-github-username \
  --build-arg GITHUB_REPO=shopizer-repo \
  --build-arg GITHUB_BRANCH=main \
  .
```

### Pros ✅
- Fastest build time (~1-2 minutes)
- Minimal image size (only runtime dependencies)
- Leverages cached CI artifacts
- Perfect for CI/CD pipelines

### Cons ❌
- Requires GitHub CLI and authentication
- Depends on GitHub Actions workflow success
- Less control over build process

---

## Environment Variables & Configuration

### For Dockerfile.ci
- `GITHUB_TOKEN` - Personal access token (required for private repos)
  ```bash
  export GITHUB_TOKEN=your_token_here
  docker build ...
  ```

### For both Dockerfiles
Pass Java options via environment:
```bash
docker run \
  -p 8080:8080 \
  -e "JAVA_OPTS=-Xmx1024m -Xms512m" \
  shopizer:local
```

---

## Running the Container

### Basic
```bash
docker run -p 8080:8080 shopizer:local
```

### With volume mounts
```bash
docker run \
  -p 8080:8080 \
  -v $(pwd)/files:/files \
  -v /tmp/shopizer-logs:/var/log/shopizer \
  shopizer:local
```

### With environment variables
```bash
docker run \
  -p 8080:8080 \
  -e "JAVA_OPTS=-Xmx2048m" \
  -e "SPRING_PROFILES_ACTIVE=production" \
  shopizer:local
```

### Health check
Both images include a health check:
```bash
docker inspect --format='{{print .State.Health.Status}}' <container-id>
```

---

## CI/CD Integration

### GitHub Actions Workflow Example
```yaml
jobs:
  build-docker:
    runs-on: ubuntu-latest
    needs: build  # Ensure build job completes first

    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: |
          cd sm-shop
          docker build \
            -f Dockerfile.ci \
            -t shopizer:${{ github.sha }} \
            --build-arg GITHUB_OWNER=${{ github.repository_owner }} \
            --build-arg GITHUB_REPO=${{ github.event.repository.name }} \
            --build-arg GITHUB_BRANCH=${{ github.ref_name }} \
            .
      
      - name: Login to Docker Registry
        run: echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
      
      - name: Push Docker image
        run: docker push shopizer:${{ github.sha }}
```

---

## Troubleshooting

### Dockerfile.local Issues
```bash
# Clear Docker build cache
docker builder prune

# Build with verbose output
docker build -f Dockerfile.local -t shopizer:local --progress=plain .

# Check build logs
docker build -f Dockerfile.local -t shopizer:local . 2>&1 | tee build.log
```

### Dockerfile.ci Issues
```bash
# Verify gh CLI authentication
gh auth status

# List recent workflow runs
gh run list --workflow=shopizer/.github/workflows/ci.yml --limit=5

# Check available artifacts
gh run view <run-id> --json artifacts

# Enable debug output during build
docker build -f Dockerfile.ci -t shopizer:ci-latest --progress=plain .
```

### General Docker Issues
```bash
# Check container logs
docker logs <container-id>

# Inspect image
docker inspect shopizer:local

# Remove dangling images
docker image prune -a

# Check disk space
docker system df
```

---

## Best Practices

1. **Use Dockerfile.ci for CD** - Faster, leverages pre-built artifacts
2. **Use Dockerfile.local for local development** - Full control, offline capable
3. **Tag images with versions** - `shopizer:v1.0.0`, `shopizer:3.2.5`
4. **Use `.dockerignore`** - Exclude unnecessary files from build context
5. **Run security scans** - Use Docker Scout or similar tools
6. **Monitor image size** - Aim for <300MB for runtime images

---

## File Structure
```
shopizer/
├── Dockerfile.local        # Local build (requires pre-built JAR)
├── Dockerfile.ci           # GitHub Actions CI download
├── build-image-from-ci.sh  # Helper script for CI image
├── DOCKER_BUILD_GUIDE.md   # This file
└── sm-shop/
    ├── Dockerfile          # Original Dockerfile (deprecated)
    ├── target/
    │   └── shopizer.jar
    └── files/
```

# Shopizer 3 (for java 17 +) (tested with Java 11, 17)

3.2.7



[![last_version](https://img.shields.io/badge/last_version-v3.2.7-blue.svg?style=flat)](https://github.com/shopizer-ecommerce/shopizer/tree/3.2.7)
[![Official site](https://img.shields.io/website-up-down-green-red/https/shields.io.svg?label=official%20site)](http://www.shopizer.com/)
[![Docker Pulls](https://img.shields.io/docker/pulls/shopizerecomm/shopizer.svg)](https://hub.docker.com/r/shopizerecomm/shopizer)
[![stackoverflow](https://img.shields.io/badge/shopizer-stackoverflow-orange.svg?style=flat)](http://stackoverflow.com/questions/tagged/shopizer)
[![CI Pipeline](https://github.com/shopizer-ecommerce/shopizer/actions/workflows/ci.yml/badge.svg)](https://github.com/shopizer-ecommerce/shopizer/actions/workflows/ci.yml)


Java open source e-commerce software

Headless commerce and Rest api for ecommerce

- Catalog
- Shopping cart
- Checkout
- Merchant
- Order
- Customer
- User

Shopizer Headless commerce consists of the following components:


Access the headless api: http://localhost:8080/swagger-ui.html


See the demo: [**New demo on the way 2025]
-------------------
Headless demo Available soon

1.  Run from Docker images:

From the command line:

```
docker run -p 8080:8080 shopizerecomm/shopizer:latest
```
       
2. Run the administration tool

⋅⋅⋅ Requires the java backend to be running

```
docker run \
 -e "APP_BASE_URL=http://localhost:8080/api" \
 -p 82:80 shopizerecomm/shopizer-admin
```


3. Run react shop sample site

⋅⋅⋅ Requires the java backend to be running

```
docker run \
 -e "APP_MERCHANT=DEFAULT"
 -e "APP_BASE_URL=http://localhost:8080"
 -p 80:80 shopizerecomm/shopizer-shop-reactjs
```

API documentation:
-------------------


Get the source code:
-------------------
Clone the repository:
     
	 $ git clone git://github.com/shopizer-ecommerce/shopizer.git
	 

To build the application:
-------------------

1. Shopizer backend


From the command line:

	$ cd shopizer
	$ mvnw clean install
	$ cd sm-shop
	$ mvnw spring-boot:run

2. Shopizer admin

Form compiling and running Shopizer admin consult the repo README file

3. Shop sample site

Form compiling and running Shopizer admin consult the repo README file



CI/CD Pipeline (GitHub Actions):
-------------------

The project includes a GitHub Actions workflow at [`.github/workflows/ci.yml`](.github/workflows/ci.yml) that automatically **tests** every push/PR and **builds + publishes** Docker artifacts on merges to `main`/`master`.

#### Workflow Overview

| Job | Trigger | What it does |
|---|---|---|
| **test** | Push or PR on `main`, `master`, `develop` | Runs all Maven tests against a MySQL 8 service container |
| **build** | Push to `main` or `master` (after tests pass) | Packages `shopizer.jar`, uploads it as a workflow artifact, and pushes a Docker image to GitHub Container Registry (`ghcr.io`) |

#### Workflow Jobs Detail

**`test` job:**
- Boots a MySQL 8.0 service container with the `SALESMANAGER` database
- Restores the Maven dependency cache for fast builds
- Runs `./mvnw test` with `spring.profiles.active=mysql`
- On failure, uploads Surefire XML reports as downloadable artifacts (7-day retention)

**`build` job (main/master only):**
- Packages the fat JAR: `./mvnw package -DskipTests -pl sm-shop -am`
- Uploads `shopizer.jar` as a GitHub Actions artifact (30-day retention, named `shopizer-jar-<git-sha>`)
- Builds and pushes the Docker image to `ghcr.io/<owner>/shopizer:latest` and `ghcr.io/<owner>/shopizer:<sha>` using the built-in `GITHUB_TOKEN` — **no extra secrets required**

#### One-time GitHub Repository Setup

Before pushing, enable write access for `GITHUB_TOKEN` so it can push Docker images to GHCR:

> **Repo → Settings → Actions → General → Workflow permissions → Select "Read and write permissions"**

#### Viewing CI Results

Navigate to the **Actions** tab on your GitHub repository to see live pipeline runs, test logs, and downloadable artifacts.


Full-Stack Docker Compose:
-------------------

The `docker-compose.yml` file has been moved to the **`shopizer-infra`** repository, where it now orchestrates the complete stack: MySQL, the Spring Boot backend, the Angular admin UI, and the React storefront.

Quick-start:

```bash
# 1. Build all three images (from each repo's root)
cd ../shopizer              && ./build-image-from-ci.sh <owner> shopizer
cd ../shopizer-admin        && ./build-image-from-ci.sh <owner> shopizer-admin
cd ../shopizer-shop-reactjs && ./build-image-from-ci.sh <owner> shopizer-shop-reactjs

# 2. Start all services
cd ../shopizer-infra && docker compose up -d
```

| Service | URL |
|---|---|
| Backend API / Swagger | http://localhost:8080/swagger-ui.html |
| Admin UI | http://localhost:4200 |
| React Shop | http://localhost:3000 |

See [`shopizer-infra/README.md`](../shopizer-infra/README.md) § "Quick-Start (Local Dev Compose)" for full details and environment variable reference.


Running Locally from CI Artifacts (backend only):
-------------------

The [`run-local.sh`](run-local.sh) script lets you pull the latest CI-built artifact and run **the Shopizer backend** on your machine without building from source. For the full stack (backend + admin + shop), see the `shopizer-infra` compose file above.

#### Prerequisites

| Tool | Required for | Install |
|---|---|---|
| `docker` | All modes | [docs.docker.com](https://docs.docker.com/get-docker/) |
| `java` 11+ | `--mode jar`, `--mode local` | [adoptium.net](https://adoptium.net/) |
| `gh` (GitHub CLI) | `--mode jar` only | [cli.github.com](https://cli.github.com/) |

#### Mode 1: Docker (default) — Pull and run the Docker image from ghcr.io

Requires the GitHub Actions CI to have completed at least once on `main`/`master`.

```bash
chmod +x run-local.sh

# Pull latest image from ghcr.io and run alongside a local MySQL container
./run-local.sh

# Or specify an image tag explicitly
./run-local.sh --mode docker --tag abc1234
```

The script will automatically authenticate to `ghcr.io` using your `gh` CLI token if you are logged in (`gh auth login`). If the image is not found, follow the printed instructions.

This will:
1. Log in to `ghcr.io` via `gh auth token` (seamless if `gh` CLI is authenticated)
2. Pull `ghcr.io/<owner>/shopizer:latest` from GitHub Container Registry
3. Start a MySQL 8 container locally
4. Launch the Shopizer container linked to MySQL

#### Mode 2: JAR — Download the JAR artifact via GitHub CLI and run directly

Requires the GitHub Actions CI to have completed at least once on `main`/`master`.

```bash
# One-time: authenticate the GitHub CLI
gh auth login

# Download the latest shopizer.jar from GitHub Actions and run it
./run-local.sh --mode jar
```

This will:
1. Find the latest successful `ci.yml` run on `main`/`master`
2. Download the `shopizer-jar-<sha>` artifact to `/tmp/shopizer-run/`
3. Start a MySQL 8 container locally
4. Run `java -jar shopizer.jar` with the MySQL spring profile

#### Mode 3: Local — Build from source and run (no CI required)

Use this when the CI pipeline hasn't run yet, or you want to test local changes.

```bash
./run-local.sh --mode local
```

This will:
1. Run `./mvnw package -DskipTests -pl sm-shop -am` to build the fat JAR
2. Start a MySQL 8 container locally
3. Run `java -jar sm-shop/target/shopizer.jar` with the MySQL spring profile

#### All Options

```
./run-local.sh [OPTIONS]

  --mode docker   Pull Docker image from ghcr.io and run  (default)
  --mode jar      Download JAR from GitHub Actions and run with java
  --mode local    Build from source locally and run (no CI artifacts needed)
  --owner <name>  GitHub owner/org (auto-detected from git remote)
  --tag <tag>     Docker image tag to pull (default: latest)
  --help          Show help
```

#### After startup, the app is available at:

| Endpoint | URL |
|---|---|
| REST API / Swagger UI | http://localhost:8080/swagger-ui.html |
| Health check | http://localhost:8080/actuator/health |
| MySQL | `localhost:3306` — db: `SALESMANAGER` |

> The application may take 30–60 seconds to fully initialize on first boot.

#### Stopping the services

You can stop the running services in two ways:

**Option 1: Press Ctrl+C** in the terminal where `run-local.sh` is running
- The script will automatically clean up all Docker containers and Java processes

**Option 2: Use the `stop-local.sh` script** (useful when services are running in the background)

```bash
# Stop MySQL and Shopizer services normally
./stop-local.sh

# Force kill if processes or containers are stuck
./stop-local.sh --force
```

The `stop-local.sh` script will:
- Stop and remove Docker containers (`shopizer-mysql`, `shopizer-app`)
- Kill any lingering Java processes (from jar or local modes)
- Optionally force-kill processes on ports 8080 and 3306 with `--force` flag


### Access the application:
-------------------

Access the headless web application at: http://localhost:8080/swagger-ui.html


The instructions above will let you run the application with default settings and configurations.
Please read the instructions on how to connect to MySQL, configure an email server and configure other subsystems



### Documentation:
-------------------

Documentation available [<https://shopizer-ecommerce.github.io/documentation/>](http://localhost:8080/swagger-ui/index.html)

ChatOps <https://shopizer.slack.com>  - Join our Slack channel <https://communityinviter.com/apps/shopizer/shopizer>

More information is available on shopizer web site here <http://www.shopizer.com>

### Participation:
-------------------

If you have interest in giving feedback or for participating to Shopizer project in any way
Feel to use the contact form <http://www.shopizer.com/contact.html> and share your email address
so we can send an invite to our Slack channel

### How to Contribute:
-------------------
Fork the repository to your GitHub account

Clone from fork repository
-------------------

       $ git clone https://github.com/yourusername/shopizer.git

Build application according to steps provided above


Create new branch in your repository
-------------------

	   $ git checkout -b branch-name


Push your changes to Shopizer
-------------------

Please open a PR (pull request) in order to have your changes merged to the upstream



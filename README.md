# Antigravity 2.0 Headless Docker Container

Runs Google Antigravity 2.0 (`language_server` + embedded web UI) as a headless web server inside Docker, downloading a pinned official release archive directly from Google's release servers during `docker build`.

> **Note on Pre-built Images:** Pre-built container images are not publicly distributed for this repository. Under the [Google Antigravity Additional Terms of Service](https://antigravity.google/terms) and the incorporated [Google Terms of Service](https://policies.google.com/terms) (*"Software in Google services"*), the downloadable software license is personal and prohibits copying or redistributing Google's software binaries. Please build the image locally from this `Dockerfile` or push only to a private container registry for personal use.

## Updating the Pinned Version

The [`Dockerfile`](Dockerfile) is pinned via `ANTIGRAVITY_VERSION` and `ANTIGRAVITY_EXECUTION_ID`. Use [`update_version.py`](update_version.py) to check or update the pinned release:

```bash
./update_version.py           # Updates Dockerfile & docker-compose.yml to the latest release
./update_version.py 2.24.0    # Pins to a specific release version
./update_version.py --check   # Checks for updates without modifying files
./update_version.py --list    # Lists available official versions
```

## Build, Tag & Publish (Private Registry)

Use [`publish.sh`](publish.sh) to build and tag the image with the pinned Antigravity version (`:${VERSION}`, `:${MAJOR}.${MINOR}`, and `:latest`), and optionally push to a private Google Cloud Artifact Registry repository:

```bash
# Build and tag locally (antigravity-headless:2.28.2, :2.28, :latest)
./publish.sh

# Build, tag, and push to a private Artifact Registry repo
./publish.sh --push <region>-docker.pkg.dev/<project>/<repo>/antigravity-headless
```

## Running the Container

### Using Docker Compose

```bash
docker compose up -d --build
```

If authenticating for the first time, check the logs for the Google OAuth URL and paste the authorization code by attaching to the container:

```bash
docker compose logs -f
docker attach antigravity-headless
```

To reuse your existing host authentication and state instead of isolated volumes, bind-mount `~/.gemini` and `~/.config/antigravity`:

```bash
docker run -it --rm \
  -p 8080:8080 \
  -p 8443:8443 \
  -v "$HOME/.gemini:/home/antigravity/.gemini" \
  -v "$HOME/.config/antigravity:/home/antigravity/.config/antigravity" \
  -v "$PWD:/workspace" \
  antigravity-headless:latest
```

Then open `http://localhost:8080/` (or `https://localhost:8443/`) in your browser.

## Environment Variables

- `HTTP_PORT` (default: `8080`): Plain HTTP port.
- `HTTPS_PORT` (default: `8443`): HTTPS port.
- `REMOTE_ACCESSIBLE` (default: `1`): Bind to `0.0.0.0` (`1`) or `127.0.0.1` (`0`).
- `CSRF_TOKEN`: Optional fixed CSRF token (auto-generated UUID by default).

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--push] [--platform <platforms>] [IMAGE_REPO]

Builds and tags the Antigravity headless container image using the version
pinned in Dockerfile (:VERSION, :MAJOR.MINOR, and :latest).

Options:
  --push                  Push all tags to the target registry after building
  --platform <platforms>  Target platform(s) for buildx (e.g., linux/amd64,linux/arm64)
  -h, --help              Show this help message

Environment / Arguments:
  IMAGE_REPO              Full image repository name (default: antigravity-headless, or
                          e.g. us-central1-docker.pkg.dev/my-project/my-repo/antigravity-headless)
EOF
}

PUSH=0
PLATFORM=""
IMAGE_REPO="${IMAGE_REPO:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push)
      PUSH=1
      shift
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      IMAGE_REPO="$1"
      shift
      ;;
  esac
done

IMAGE_REPO="${IMAGE_REPO:-antigravity-headless}"
VERSION="$(sed -n 's/^ARG ANTIGRAVITY_VERSION=//p' "${DOCKERFILE}")"
if [[ -z "${VERSION}" ]]; then
  echo "Error: Could not extract ANTIGRAVITY_VERSION from ${DOCKERFILE}" >&2
  exit 1
fi
MINOR_VERSION="${VERSION%.*}"

TAGS=(
  -t "${IMAGE_REPO}:${VERSION}"
  -t "${IMAGE_REPO}:${MINOR_VERSION}"
  -t "${IMAGE_REPO}:latest"
)

echo "Building ${IMAGE_REPO} (version: ${VERSION}, minor: ${MINOR_VERSION})..."

if [[ -n "${PLATFORM}" ]]; then
  BUILD_ARGS=(buildx build --platform "${PLATFORM}" "${TAGS[@]}")
  if [[ "${PUSH}" -eq 1 ]]; then
    BUILD_ARGS+=(--push)
  else
    BUILD_ARGS+=(--load)
  fi
  docker "${BUILD_ARGS[@]}" "${SCRIPT_DIR}"
else
  docker build "${TAGS[@]}" "${SCRIPT_DIR}"
  if [[ "${PUSH}" -eq 1 ]]; then
    docker push "${IMAGE_REPO}:${VERSION}"
    docker push "${IMAGE_REPO}:${MINOR_VERSION}"
    docker push "${IMAGE_REPO}:latest"
  fi
fi

echo "Done: ${IMAGE_REPO}:${VERSION}"

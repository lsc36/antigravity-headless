#!/usr/bin/env python3
"""Fetch official Antigravity releases and update pinned version in Dockerfile & docker-compose.yml."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
import urllib.request

RELEASES_URL = (
    "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"
)
BASE_DIR = Path(__file__).resolve().parent
DOCKERFILE_PATH = BASE_DIR / "Dockerfile"
COMPOSE_PATH = BASE_DIR / "docker-compose.yml"

VERSION_RE = re.compile(r"^(ARG\s+ANTIGRAVITY_VERSION=)(.+)$", re.MULTILINE)
EXEC_ID_RE = re.compile(r"^(ARG\s+ANTIGRAVITY_EXECUTION_ID=)(.+)$", re.MULTILINE)
COMPOSE_VER_RE = re.compile(r"(\$\{ANTIGRAVITY_VERSION:-)([^}]+)(\})")


def fetch_releases() -> list[dict[str, str]]:
    req = urllib.request.Request(
        RELEASES_URL,
        headers={"User-Agent": "antigravity-headless-updater/1.0"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    if not isinstance(data, list) or not data:
        raise RuntimeError("Unexpected empty or invalid response from releases API.")
    return data


def read_current_pin(dockerfile: Path) -> tuple[str | None, str | None]:
    content = dockerfile.read_text(encoding="utf-8")
    ver_match = VERSION_RE.search(content)
    exec_match = EXEC_ID_RE.search(content)
    return (
        ver_match.group(2).strip() if ver_match else None,
        exec_match.group(2).strip() if exec_match else None,
    )


def update_files(
    dockerfile: Path, compose_file: Path, version: str, execution_id: str
) -> None:
    content = dockerfile.read_text(encoding="utf-8")
    content, n_ver = VERSION_RE.subn(rf"\g<1>{version}", content)
    content, n_exec = EXEC_ID_RE.subn(rf"\g<1>{execution_id}", content)
    if n_ver == 0 or n_exec == 0:
        raise RuntimeError(
            f"Could not find ANTIGRAVITY_VERSION / ANTIGRAVITY_EXECUTION_ID in {dockerfile}"
        )
    dockerfile.write_text(content, encoding="utf-8")

    if compose_file.is_file():
        compose_content = compose_file.read_text(encoding="utf-8")
        compose_content = COMPOSE_VER_RE.sub(
            rf"\g<1>{version}\g<3>", compose_content
        )
        compose_file.write_text(compose_content, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Update pinned Antigravity version in Dockerfile and docker-compose.yml."
    )
    parser.add_argument(
        "version",
        nargs="?",
        default="latest",
        help="Target version to pin (default: 'latest').",
    )
    parser.add_argument(
        "-l",
        "--list",
        action="store_true",
        help="List available official releases and exit.",
    )
    parser.add_argument(
        "-c",
        "--check",
        action="store_true",
        help="Check whether Dockerfile is up to date without modifying it.",
    )
    parser.add_argument(
        "-f",
        "--dockerfile",
        type=Path,
        default=DOCKERFILE_PATH,
        help="Path to Dockerfile (default: ./Dockerfile).",
    )
    args = parser.parse_args()

    releases = fetch_releases()

    if args.list:
        for r in releases:
            print(f"{r['version']}\t{r['execution_id']}")
        return 0

    if not args.dockerfile.is_file():
        print(f"Error: Dockerfile not found at {args.dockerfile}", file=sys.stderr)
        return 1

    if args.version == "latest":
        target = releases[0]
    else:
        target = next((r for r in releases if r.get("version") == args.version), None)
        if target is None:
            print(
                f"Error: Version '{args.version}' not found in official releases.",
                file=sys.stderr,
            )
            return 1

    new_version = target["version"]
    new_exec_id = target["execution_id"]
    cur_version, cur_exec_id = read_current_pin(args.dockerfile)

    if cur_version == new_version and cur_exec_id == new_exec_id:
        print(
            f"Dockerfile is already pinned to {new_version} (execution_id: {new_exec_id})."
        )
        return 0

    if args.check:
        print(
            f"Update available: {cur_version} ({cur_exec_id}) -> {new_version} ({new_exec_id})"
        )
        return 1

    update_files(args.dockerfile, COMPOSE_PATH, new_version, new_exec_id)
    print(
        f"Updated pinned version: {cur_version or 'none'} -> {new_version} (execution_id: {new_exec_id})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

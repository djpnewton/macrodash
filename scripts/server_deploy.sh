#!/usr/bin/env bash
#
# Deploys the API server to Fly.io.
#
#   ./scripts/server_deploy.sh [flyctl deploy args...]
#
# Thin wrapper around macrodash_server/deploy.sh, which handles building,
# Fly authentication and dart_frog discovery.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$(dirname "$SCRIPT_DIR")/macrodash_server/deploy.sh" remote release "$@"

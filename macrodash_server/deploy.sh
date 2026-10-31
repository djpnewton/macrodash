#!/usr/bin/env bash
#
# Builds and runs or deploys the API server.
#
#   ./deploy.sh local [debug|release]
#   ./deploy.sh remote [release] [flyctl deploy args...]
#
# `remote` builds with `dart_frog build` and deploys build/ to Fly (configured
# in fly.toml). Extra arguments are forwarded to `flyctl deploy`.
#
# Environment:
#   FLY_API_TOKEN  Fly access token for `remote`. When unset, `flyctl auth
#                  whoami` is tried, then the token stored in ~/.fly/config.yml
#                  (flyctl does not always read it on its own). Never printed.
#   FRED_API_KEY   Required by the /sov/* routes in `local` mode.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# Run from macrodash_server/ regardless of the caller's working directory.
cd "$SCRIPT_DIR"

usage() {
  cat <<'EOF'
Usage: ./deploy.sh <local|remote> [debug|release] [flyctl deploy args...]

Modes:
  local    Run the server locally. debug uses `dart_frog dev`; release builds
           and runs build/bin/server.dart.
  remote   Build with `dart_frog build` and deploy build/ to Fly. Release only.

Remote arguments after the build mode are forwarded to `flyctl deploy`, e.g.
  ./deploy.sh remote release --ha=false
EOF
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' is not on PATH" >&2
    exit 1
  }
}

ensure_fly_auth() {
  if [[ -n ${FLY_API_TOKEN:-} ]]; then
    return
  fi
  if flyctl auth whoami >/dev/null 2>&1; then
    return
  fi

  local config="${FLY_CONFIG:-$HOME/.fly/config.yml}" token=""
  if [[ -r $config ]]; then
    token=$(sed -n 's/^access_token:[[:space:]]*//p' "$config" | head -n 1)
    token=${token#\"}
    token=${token%\"}
    token=${token#\'}
    token=${token%\'}
  fi
  if [[ -z $token ]]; then
    echo "error: not logged in to Fly; run 'flyctl auth login' or set FLY_API_TOKEN" >&2
    exit 1
  fi
  export FLY_API_TOKEN="$token"
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

# The globally activated CLI is often installed to ~/.pub-cache/bin, which is
# not always on PATH.
if ! command -v dart_frog >/dev/null 2>&1; then
  pub_bin="${PUB_CACHE:-$HOME/.pub-cache}/bin"
  if [[ -x $pub_bin/dart_frog ]]; then
    PATH="$pub_bin:$PATH"
    export PATH
  fi
fi

DEPLOY_TYPE=$1
BUILD_MODE=${2:-release} # Default to 'release' if no second argument is provided
# Remaining arguments are forwarded to `flyctl deploy`.
shift $(( $# >= 2 ? 2 : 1 ))

case "$DEPLOY_TYPE" in
  local)
    require dart
    echo "Building and deploying locally..."
    echo "Build mode: $BUILD_MODE"

    if [[ $BUILD_MODE == debug ]]; then
      dart_frog dev
    elif [[ $BUILD_MODE == release ]]; then
      dart_frog build
      dart build/bin/server.dart
    else
      echo "Invalid build mode. Please choose 'debug' or 'release'." >&2
      exit 1
    fi
    ;;
  remote)
    if [[ $BUILD_MODE != release ]]; then
      echo "Remote deployment can only be done in 'release' mode." >&2
      exit 1
    fi

    require dart
    require flyctl
    ensure_fly_auth

    echo "Building and deploying remotely in release mode..."
    dart_frog build
    cd build
    flyctl deploy "$@"
    ;;
  *)
    echo "error: unknown mode '$DEPLOY_TYPE'" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac
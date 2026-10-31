#!/usr/bin/env bash
#
# Runs the app or the local API server.
#
#   ./scripts/run.sh            # client (default)
#   ./scripts/run.sh client     # client
#   ./scripts/run.sh server     # server
#
# Arguments after the mode are forwarded to `flutter run` / `dart_frog dev`.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# `dart_frog dev` (and `flutter run`) put the tty in raw/no-echo mode for their
# interactive keys and do not always restore it when interrupted, which leaves
# the shell not echoing what you type. Snapshot the tty and always put it back.
saved_tty=""
if [[ -t 0 ]]; then
  saved_tty=$(stty -g 2>/dev/null || true)
fi

restore_terminal() {
  if [[ -n $saved_tty ]]; then
    stty "$saved_tty" 2>/dev/null || stty sane 2>/dev/null || true
  fi
}

trap restore_terminal EXIT

usage() {
  cat <<'EOF'
Usage: ./scripts/run.sh [client|server] [args...]

Modes:
  client   Run the Flutter app (default). Defaults to the linux desktop device;
           pass -d/--device to override it.
  server   Run the local dart_frog API server on :8080 (override with --port).

Arguments after the mode are passed through:
  ./scripts/run.sh client -d chrome
  ./scripts/run.sh server --port 8081

Environment:
  GDK_BACKEND   Defaults to 'x11' for the client, because GTK3 crashes on
                Wayland with gnome-settings-daemon 50+ ("Settings schema
                ... does not contain a key named 'antialiasing'").
  FRED_API_KEY  Required by the /sov/* routes; read from
                macrodash_server/env.sh when present.
EOF
}

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' is not on PATH" >&2
    exit 1
  }
}

run_client() {
  require flutter
  local -a args=("$@")
  local has_device=false
  local arg
  for arg in "${args[@]}"; do
    case "$arg" in
      -d | --device | --device=* | -d=*) has_device=true ;;
    esac
  done
  if [[ $has_device == false ]]; then
    args=(-d linux "${args[@]}")
  fi
  export GDK_BACKEND="${GDK_BACKEND:-x11}"
  cd "$ROOT_DIR"
  flutter run "${args[@]}"
}

run_server() {
  require dart
  cd "$ROOT_DIR/macrodash_server"
  if [[ -f env.sh ]]; then
    set -a
    # shellcheck source=/dev/null
    . ./env.sh
    set +a
  elif [[ -z ${FRED_API_KEY:-} ]]; then
    echo "warning: env.sh missing and FRED_API_KEY unset; /sov/* routes will fail" >&2
  fi
  local status=0
  if command -v dart_frog >/dev/null 2>&1; then
    dart_frog dev "$@" || status=$?
  else
    # dart_frog_cli is activated globally but ~/.pub-cache/bin is often not on PATH.
    dart pub global run dart_frog_cli:dart_frog dev "$@" || status=$?
  fi
  if ((status != 0)); then
    cat >&2 <<'EOF'

hint: the dev server exited immediately. The usual cause is the inotify watch
      limit being exhausted (error 28 / "No space left on device"), which makes
      dart_frog's hot-reload watcher fail right after it reports "Running on".
        cat /proc/sys/fs/inotify/max_user_watches
        sudo sysctl -w fs.inotify.max_user_watches=524288
      Or run without the file watcher:
        cd macrodash_server && dart_frog build && dart build/bin/server.dart
EOF
  fi
  return "$status"
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

mode=client
if [[ $# -gt 0 && $1 != -* ]]; then
  mode=$1
  shift
fi

case "$mode" in
  client)
    run_client "$@"
    ;;
  server)
    run_server "$@"
    ;;
  *)
    echo "error: unknown mode '$mode'" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Toggle Handy transcription on macOS by sending SIGUSR2 to the running Handy process.

Usage:
  handy-toggle-transcribe-macos.sh [--launch]

Options:
  --launch   If Handy is not running, launch it (bundle id: com.pais.handy) and
             wait briefly for it to start, then send SIGUSR2.

Notes:
  - This toggles (start/stop). It is not an idempotent "start only" or "stop only".
  - Intended for external hotkey tools like BetterTouchTool.
EOF
}

want_launch=0
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--launch" ]]; then
  want_launch=1
elif [[ "${1:-}" != "" ]]; then
  echo "Unknown argument: ${1}" >&2
  usage >&2
  exit 2
fi

find_handy_pid() {
  # Primary: process name (macOS runs the app binary as "handy").
  local pid=""
  pid="$(pgrep -x "handy" 2>/dev/null | head -n1 || true)"
  if [[ -n "${pid}" ]]; then
    echo "${pid}"
    return 0
  fi

  # Secondary: some environments may show the process name as "Handy".
  pid="$(pgrep -x "Handy" 2>/dev/null | head -n1 || true)"
  if [[ -n "${pid}" ]]; then
    echo "${pid}"
    return 0
  fi

  # Fallback: match the app bundle binary path.
  pid="$(pgrep -f "/Handy\\.app/Contents/MacOS/handy" 2>/dev/null | head -n1 || true)"
  if [[ -n "${pid}" ]]; then
    echo "${pid}"
    return 0
  fi

  return 1
}

pid="$(find_handy_pid || true)"
if [[ -z "${pid}" ]]; then
  if [[ "${want_launch}" -eq 1 ]]; then
    # Launch by bundle identifier; this is usually the fastest/cleanest way to start the app.
    open -b "com.pais.handy" || true

    # Wait up to ~1s for the process to appear.
    for _ in {1..20}; do
      pid="$(find_handy_pid || true)"
      if [[ -n "${pid}" ]]; then
        break
      fi
      sleep 0.05
    done
  fi
fi

if [[ -z "${pid}" ]]; then
  echo "Handy is not running (process name: Handy). Start the app, or rerun with --launch." >&2
  exit 1
fi

kill -USR2 "${pid}"

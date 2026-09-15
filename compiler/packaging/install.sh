#!/bin/sh
# dcflight installer (macOS / Linux).
# Usage:  curl -fsSL https://github.com/dotcorr/dcflight/releases/latest/download/install.sh | sh
# Or:     ./install.sh [version]
set -eu
REPO="${DCFLIGHT_REPO:-dotcorr/dcflight}"
VERSION="${1:-${DCFLIGHT_VERSION:-latest}}"
ROOT="$HOME/.dcflight"
mkdir -p "$ROOT/bin"

have() { command -v "$1" >/dev/null 2>&1; }

PY=python3
if ! have "$PY"; then
  echo "Python 3.9+ is required. Install it first:" >&2
  echo "  macOS:   brew install python3  (or xcode-select --install)" >&2
  echo "  Linux:   apt install python3  /  dnf install python3" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if [ "$VERSION" = "latest" ]; then
  URL="https://github.com/$REPO/releases/latest/download/dcflight_compiler-py3-none-any.whl"
else
  URL="https://github.com/$REPO/releases/download/$VERSION/dcflight_compiler-py3-none-any.whl"
fi
echo "Downloading $URL"
curl -fsSL -o "$TMP/dcflight.whl" "$URL"

# User install; --break-system-packages for PEP 668 managed environments.
"$PY" -m pip install --user --upgrade "$TMP/dcflight.whl" >/dev/null 2>&1 || \
"$PY" -m pip install --user --break-system-packages --upgrade "$TMP/dcflight.whl"

# Stable launchers in ~/.dcflight/bin regardless of pip's user bin location.
"$PY" - "$ROOT/bin" <<'PY'
import os, sys
from dcflight import __version__
target = sys.argv[1]
os.makedirs(target, exist_ok=True)
py = sys.executable
for name, code in (
    ('dcflight', 'from dcflight.cli import main; raise SystemExit(main())'),
    ('dcflight-mcp', 'from dcflight.mcp_server import main; raise SystemExit(main())')):
    path = os.path.join(target, name)
    with open(path, 'w') as f:
        f.write('#!/bin/sh\nexec %s -c %s "$@"\n' % (py, repr(code)))
    os.chmod(path, 0o755)
print('installed dcflight', __version__)
PY

LINE='export PATH="$HOME/.dcflight/bin:$PATH"'
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  grep -qs "dcflight/bin" "$rc" 2>/dev/null || echo "$LINE" >> "$rc" 2>/dev/null || true
done

echo
echo 'dcflight installed. Open a new shell or run:  export PATH="$HOME/.dcflight/bin:$PATH"'
echo 'Check native toolchains (Xcode, Android, Dart):  dcflight doctor'
echo 'Auto-install missing dev toolchains:             dcflight doctor --install'
echo 'Create an app:                                   dcflight create my-app && cd my-app'
echo 'Wire an MCP agent client:                        dcflight mcp-config --client claude'

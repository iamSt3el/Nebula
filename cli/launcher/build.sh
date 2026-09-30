#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "==> Building the nebula command..."

_CC=$(command -v cc 2>/dev/null || command -v gcc 2>/dev/null || command -v clang 2>/dev/null || true)
if [[ -z "$_CC" ]]; then
  echo "ERROR: no C compiler found (cc, gcc or clang)" >&2; exit 1
fi

mkdir -p build
"$_CC" -O2 -Wall -Wextra -o build/nebula nebula.c

if [[ "$1" == "--install" ]]; then
  dest="${2:-/usr/local/bin}"
  echo "==> Installing to $dest/nebula ..."
  if [[ -w "$dest" ]]; then
    install -Dm755 build/nebula "$dest/nebula"
  else
    sudo install -Dm755 build/nebula "$dest/nebula"
  fi
fi

echo "==> Done."

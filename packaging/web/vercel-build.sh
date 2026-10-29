#!/usr/bin/env bash
# Build the browser version on Vercel (vercel.json `buildCommand`). Output: dist/web.
#
# Vercel's build image has no Rust, so this installs rustup with the wasm32 target, and downloads
# prebuilt trunk and wasm-bindgen (matching the wasm-bindgen version in Cargo.lock) into
# $HOME/.local/bin. Hosting notes: packaging/web/README.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TRUNK_VERSION=0.21.14
BIN="$HOME/.local/bin"
mkdir -p "$BIN"
export PATH="$HOME/.cargo/bin:$BIN:$PATH"

if ! command -v rustup >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
    sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path
fi
rustup target add wasm32-unknown-unknown

WB_VERSION="$(grep -A1 '^name = "wasm-bindgen"$' "$ROOT/Cargo.lock" | sed -n 's/^version = "\(.*\)"$/\1/p')"
[[ -n "$WB_VERSION" ]] || { echo "error: wasm-bindgen version not found in Cargo.lock" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -sSfL "https://github.com/trunk-rs/trunk/releases/download/v$TRUNK_VERSION/trunk-x86_64-unknown-linux-gnu.tar.gz" |
  tar xz -C "$TMP"
install "$TMP/trunk" "$BIN/trunk"
curl -sSfL "https://github.com/wasm-bindgen/wasm-bindgen/releases/download/$WB_VERSION/wasm-bindgen-$WB_VERSION-x86_64-unknown-linux-musl.tar.gz" |
  tar xz -C "$TMP"
install "$TMP/wasm-bindgen-$WB_VERSION-x86_64-unknown-linux-musl/wasm-bindgen" "$BIN/wasm-bindgen"

cd "$ROOT/apps/pdfcraft-web"
trunk build --release --skip-version-check

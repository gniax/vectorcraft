#!/bin/sh
# Put the web build the iPad app bundles into packaging/ios/web.
#   packaging/ios/fetch-web.sh           download the latest one CI built (no Rust needed)
#   packaging/ios/fetch-web.sh --build   build it here (needs Rust, the wasm32 target and trunk)
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
dest="$here/web"
url="https://github.com/gniax/vectorcraft-ipad/releases/download/ipad-web-latest/vectorcraft-web.zip"

if [ "${1:-}" = "--build" ]; then
  (cd "$root/apps/vectorcraft-web" && trunk build --release)
  rm -rf "$dest"
  cp -R "$root/dist/web" "$dest"
else
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  echo "Downloading $url"
  curl -fL --progress-bar -o "$tmp/web.zip" "$url"
  rm -rf "$dest"
  mkdir -p "$dest"
  unzip -q "$tmp/web.zip" -d "$dest"
fi
test -f "$dest/index.html"
echo "Web build ready in $dest — now open packaging/ios/VectorCraft.xcodeproj in Xcode."

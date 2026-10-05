#!/bin/sh
# Installs a prebuilt Samaya for x86_64 Linux into ~/.local, without compiling:
#
#   curl -fsSL https://git.hegdeatri.com/hegdeatri/samaya-releases/raw/branch/main/install.sh | sh
#   curl -fsSL …/install.sh | sh -s -- v0.1.0    # a specific version
#
# PREFIX changes where it goes (default ~/.local). Running it again upgrades.
set -eu

host=https://git.hegdeatri.com
repo=hegdeatri/samaya-releases
prefix=${PREFIX:-$HOME/.local}

if [ "$(uname -sm)" != "Linux x86_64" ]; then
  echo "Prebuilt Samaya is for x86_64 Linux only; build it from source instead." >&2
  exit 1
fi

tag=${1:-}
if [ -z "$tag" ]; then
  tag=$(curl -fsSL "$host/api/v1/repos/$repo/releases/latest" |
    sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p')
fi
[ -n "$tag" ] || { echo "Could not find the latest release." >&2; exit 1; }

name="samaya-${tag#v}-x86_64-linux"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL -o "$work/$name.tar.gz" "$host/$repo/releases/download/$tag/$name.tar.gz"
curl -fsSL -o "$work/$name.tar.gz.sha256" "$host/$repo/releases/download/$tag/$name.tar.gz.sha256"
(cd "$work" && sha256sum -c "$name.tar.gz.sha256" >/dev/null)
tar -C "$work" -xzf "$work/$name.tar.gz"

install -Dm755 "$work/$name/bin/samaya" "$prefix/bin/samaya"
install -Dm644 "$work/$name/share/applications/samaya.desktop" \
  "$prefix/share/applications/samaya.desktop"
install -Dm644 "$work/$name/share/icons/hicolor/128x128/apps/samaya.png" \
  "$prefix/share/icons/hicolor/128x128/apps/samaya.png"

echo "Installed Samaya $tag to $prefix/bin/samaya."
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) echo "Add $prefix/bin to your PATH to run it as 'samaya'." ;;
esac

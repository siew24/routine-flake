# shellcheck shell=bash
#
# Refresh sources.json from the rolling Routine download URL.
#
# Routine publishes no releases list and no versioned URL -- there is one
# unversioned AppImage that changes under you. So "updating" means: fetch it,
# hash it, and dig the version out of the image itself.

set -euo pipefail

URL="https://releases.routine.co/routine/linux/Routine.AppImage"
SYSTEM="x86_64-linux"
SOURCES="${PWD}/sources.json"

if [[ ! -f "$SOURCES" ]]; then
  echo "routine-update: $SOURCES not found -- run this from the flake root" >&2
  exit 1
fi

echo "==> fetching $URL"
prefetch="$(nix store prefetch-file --json --name Routine.AppImage "$URL")"
hash="$(jq -r '.hash' <<<"$prefetch")"
store="$(jq -r '.storePath' <<<"$prefetch")"
echo "    sha256: $hash"

old_hash="$(jq -r --arg s "$SYSTEM" '.[$s].sha256 // ""' "$SOURCES")"
old_version="$(jq -r --arg s "$SYSTEM" '.[$s].version // "?"' "$SOURCES")"

if [[ "$hash" == "$old_hash" ]]; then
  echo "==> unchanged, still $old_version"
  exit 0
fi

# The version lives only inside the image, as X-AppImage-Version in
# routine.desktop. Read it straight out of the squashfs payload.
#
# Do NOT execute the AppImage to get it. With programs.appimage.binfmt enabled,
# flags like --appimage-extract are handed to the *app* rather than to the
# AppImage runtime: the app launches, and its AppRun copies the running image
# over whatever path ~/.local/share/applications/routine.desktop points at,
# silently replacing that file.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# An AppImage is an ELF with the squashfs appended; the payload starts where the
# section headers end.
offset="$(readelf -h "$store" | awk '
  /Start of section headers/  { o = $5 }
  /Size of section headers/   { s = $5 }
  /Number of section headers/ { n = $5 }
  END { print o + s * n }
')"

unsquashfs -o "$offset" -d "$work/img" -no-progress "$store" routine.desktop >/dev/null

# X-AppImage-Version=2.1.1.34213 -> 2.1.1 (the trailing field is a build number)
version="$(sed -n 's/^X-AppImage-Version=//p' "$work/img/routine.desktop" | cut -d. -f1-3)"

if [[ -z "$version" ]]; then
  echo "routine-update: could not read a version from routine.desktop" >&2
  exit 1
fi

echo "==> $old_version -> $version"

tmp="$(mktemp)"
jq --arg s "$SYSTEM" --arg v "$version" --arg u "$URL" --arg h "$hash" \
  '.[$s] = { version: $v, url: $u, sha256: $h }' "$SOURCES" >"$tmp"
mv "$tmp" "$SOURCES"

echo "==> wrote $SOURCES"

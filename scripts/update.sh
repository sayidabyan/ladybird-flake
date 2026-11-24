#!/usr/bin/env bash
# Bump pkgs/ladybird/sources.json to the latest LadybirdBrowser/ladybird GitHub Release (alpha).
# Usage: scripts/update.sh [tag]
# Writes updated/old_tag/new_tag/rev/version to $GITHUB_OUTPUT when running in Actions.
set -euo pipefail

cd "$(dirname "$0")/.."
SOURCES=pkgs/ladybird/sources.json
REPO=LadybirdBrowser/ladybird
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

output() { [[ -n "${GITHUB_OUTPUT:-}" ]] && echo "$1" >>"$GITHUB_OUTPUT" || true; }

auth=()
[[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")

old_tag=$(jq -r '.tag // empty' "$SOURCES")
new_tag=${1:-$(curl -fsSL "${auth[@]}" "https://api.github.com/repos/$REPO/releases/latest" | jq -r .tag_name)}

if [[ -z "$new_tag" || "$new_tag" == "null" ]]; then
  echo "Could not determine latest release tag" >&2
  exit 1
fi

output "old_tag=$old_tag"
output "old_version=$(jq -r .version "$SOURCES")"
output "old_rev=$(jq -r .rev "$SOURCES")"
output "new_tag=$new_tag"

if [[ "$old_tag" == "$new_tag" && -z "${FORCE:-}" ]]; then
  echo "Already up to date at $old_tag"
  output "updated=false"
  exit 0
fi

echo "Updating ${old_tag:-<none>} -> $new_tag"

# Resolve the tag to a commit (prefer the peeled ref for annotated tags)
refs=$(git ls-remote "https://github.com/$REPO" "refs/tags/$new_tag" "refs/tags/$new_tag^{}")
rev=$(awk '/\^\{\}$/ {print $1}' <<<"$refs")
[[ -z "$rev" ]] && rev=$(awk 'NR==1 {print $1}' <<<"$refs")
if [[ -z "$rev" ]]; then
  echo "Tag $new_tag not found upstream" >&2
  exit 1
fi

version=$new_tag

# Source hash
prefetch=$(nix flake prefetch --json "github:$REPO/$rev")
src_hash=$(jq -r .hash <<<"$prefetch")
src_path=$(jq -r .storePath <<<"$prefetch")

# llvm-libc headers: copy the pin from upstream's vcpkg overlay port
port="$src_path/Meta/CMake/vcpkg/overlay-ports/llvm-libc"
llvm_libc_rev=$(jq -r '."version-string" // .version' "$port/vcpkg.json")
llvm_libc_sha512=$(grep -oE 'SHA512 +[0-9a-f]{128}' "$port/portfile.cmake" | awk '{print $2}')
if [[ -z "$llvm_libc_rev" || -z "$llvm_libc_sha512" ]]; then
  echo "Could not read llvm-libc pin from $port" >&2
  exit 1
fi

write_sources() {
  jq -n --arg version "$version" --arg tag "$new_tag" --arg rev "$rev" \
    --arg srcHash "$src_hash" --arg cargoHash "$1" \
    --arg llvmRev "$llvm_libc_rev" --arg llvmSha "$llvm_libc_sha512" \
    '{version: $version, tag: $tag, rev: $rev, srcHash: $srcHash, cargoHash: $cargoHash,
      llvmLibc: {rev: $llvmRev, sha512: $llvmSha}}' >"$SOURCES"
}

# Cargo vendor hash: build with a fake hash and read the real one from the mismatch error
write_sources "$FAKE_HASH"
set +e
log=$(nix build --no-link -L .#ladybird.cargoDeps 2>&1)
set -e
cargo_hash=$(grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' <<<"$log" | awk '{print $2}' | tail -n1)

if [[ -z "$cargo_hash" ]]; then
  echo "Failed to determine cargo hash:" >&2
  echo "$log" | tail -n 50 >&2
  git checkout -- "$SOURCES" 2>/dev/null || true
  exit 1
fi

write_sources "$cargo_hash"
echo "Updated to $version ($rev)"
echo "  srcHash:   $src_hash"
echo "  cargoHash: $cargo_hash"

output "updated=true"
output "version=$version"
output "rev=$rev"

#!/usr/bin/env bash
set -euo pipefail

output_name="${1:-likemedieval-windows}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd -- "$script_dir/.." && pwd)"
dist_root="$root/dist"
package_dir="$dist_root/$output_name"
zip_path="$dist_root/$output_name.zip"

required_files=(
  "likemedieval.exe"
  "EOSSDK-Win64-Shipping.dll"
  "xaudio2_9redist.dll"
)

if ! command -v zip >/dev/null 2>&1; then
  echo "Missing 'zip' command. Run this from Git Bash/WSL with zip installed." >&2
  exit 1
fi

shopt -s nullglob
eosg_dlls=("$root"/libeosg.windows.*.x86_64.dll)
shopt -u nullglob

if [ "${#eosg_dlls[@]}" -eq 0 ]; then
  echo "Missing EOSG native DLL. Export the Windows build from Godot before packaging." >&2
  exit 1
fi

for file in "${required_files[@]}"; do
  if [ ! -f "$root/$file" ]; then
    echo "Missing required export file: $file" >&2
    exit 1
  fi
done

rm -rf "$package_dir"
rm -f "$zip_path"
mkdir -p "$package_dir"

for file in "${required_files[@]}"; do
  cp "$root/$file" "$package_dir/"
done
for dll in "${eosg_dlls[@]}"; do
  cp "$dll" "$package_dir/"
done

if [ -f "$root/likemedieval.console.exe" ]; then
  cp "$root/likemedieval.console.exe" "$package_dir/"
fi

(
  cd "$dist_root"
  zip -qr "$zip_path" "$output_name"
)

for file in "${required_files[@]}"; do
  rm -f "$root/$file"
done
for dll in "${eosg_dlls[@]}"; do
  rm -f "$dll"
done
rm -f "$root/likemedieval.console.exe"

echo "Created $zip_path"
echo "Cleaned root export files"

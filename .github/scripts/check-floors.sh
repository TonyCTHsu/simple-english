#!/usr/bin/env bash
# Native Image links against the build host's toolchain, so a host newer
# than the oldest supported OS silently raises the binary's requirements.
# Both CI and the release workflow build on the oldest supported host and
# hold the binary to these floors.
set -euo pipefail

binary=libexec/simple_english/languagetool-server

os="$(uname -s)"
case "$os" in
  Linux)
    floor=GLIBC_2.35
    highest="$(objdump -T "$binary" | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
    [ -n "$highest" ] || { echo "error: no GLIBC symbols found in $binary"; exit 1; }
    [ "$(printf '%s\n' "$floor" "$highest" | sort -V | tail -1)" = "$floor" ] ||
      { echo "error: binary requires $highest, above the $floor floor"; exit 1; }
    echo "glibc floor ok: $highest"
    ;;
  Darwin)
    floor=12.0
    minos="$(otool -l "$binary" | grep -A4 LC_BUILD_VERSION | grep minos | awk '{print $NF}')"
    [ -n "$minos" ] || { echo "error: no LC_BUILD_VERSION minos in $binary"; exit 1; }
    [ "$(printf '%s\n' "$floor" "$minos" | sort -V | tail -1)" = "$floor" ] ||
      { echo "error: binary requires macOS $minos, above the $floor floor"; exit 1; }
    echo "macOS floor ok: $minos"
    ;;
  *)
    echo "error: unsupported build host $os"; exit 1
    ;;
esac

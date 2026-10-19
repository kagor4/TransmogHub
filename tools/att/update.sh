#!/bin/sh
# Пересобрать встроенную базу источников из свежей базы AllTheThings (MIT)
set -e
cd "$(dirname "$0")/../.."
TMP=$(mktemp -d)
git clone --depth 1 --filter=blob:none --sparse https://github.com/ATTWoWAddon/AllTheThings "$TMP/att"
(cd "$TMP/att" && git sparse-checkout set db/Standard && cp LICENSE "$OLDPWD/TransmogHub_Sources/LICENSE-AllTheThings.txt")
lua5.1 tools/att/build.lua "$TMP/att" TransmogHub_Sources/ATT.lua
rm -rf "$TMP"
lua5.1 tests/att.lua .

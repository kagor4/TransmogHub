#!/bin/sh
# Ежедневный выпуск официального чарта.
#   tools/charts/release.sh <путь к snapshots/TransmogHub.lua.gz> [папка secrets закрытого репозитория]
# Пересчитывает Data/Charts.lua, прогоняет тесты, коммитит в текущую ветку
# (main) и ставит тег vВЕРСИЯ.ГГГГММДД — тег запускает выпуск на CurseForge.
set -e
cd "$(dirname "$0")/../.."
SNAP="$1"
SECRETS="$2"
[ -f "$SNAP" ] || { echo "нет снимка: $SNAP"; exit 1; }
TMP="$(mktemp)"
gunzip -c "$SNAP" > "$TMP"
lua5.1 tools/charts/build.lua . "$TMP" Data/Charts.lua "" "$SECRETS"
rm -f "$TMP"
luac5.1 -p *.lua Data/*.lua
lua5.1 tests/smoke.lua . > /dev/null
lua5.1 tests/filter.lua . > /dev/null
lua5.1 tests/charts.lua . > /dev/null
if git diff --quiet -- Data/Charts.lua; then
	echo "Чарт не изменился, выпуск не нужен"
	exit 0
fi
DAY="$(date -u +%Y%m%d)"
TAG="v$(tr -d ' \n' < VERSION).$DAY"
git add Data/Charts.lua
git commit -q -m "Официальный чарт $(date -u +%Y-%m-%d)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git tag "$TAG"
git push origin HEAD
git push origin "$TAG"
echo "Выпущено: $TAG"

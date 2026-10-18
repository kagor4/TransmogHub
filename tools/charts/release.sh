#!/bin/sh
# Ежедневный выпуск официального чарта.
#   tools/charts/release.sh <путь к snapshots/TransmogHub.lua.gz> [папка secrets закрытого репозитория]
# Пересчитывает Data/Charts.lua, прогоняет тесты, коммитит в текущую ветку
# (main) и пушит его. Тег vВЕРСИЯ.ГГГГММДД и выпуск на CurseForge делает
# .github/workflows/release.yml: облачные сессии теги ставить не могут.
set -e
cd "$(dirname "$0")/../.."
SNAP="$1"
SECRETS="$2"
[ -f "$SNAP" ] || { echo "нет снимка: $SNAP"; exit 1; }
TMP="$(mktemp)"
gunzip -c "$SNAP" > "$TMP"
lua5.1 tools/charts/build.lua . "$TMP" Data/Charts.lua "" "$SECRETS" Data/Bundled.lua Data/Sources.lua
rm -f "$TMP"
luac5.1 -p *.lua Data/*.lua Locales/*.lua
lua5.1 tests/smoke.lua . > /dev/null
lua5.1 tests/filter.lua . > /dev/null
lua5.1 tests/locales.lua . > /dev/null
lua5.1 tests/charts.lua . > /dev/null
if git diff --quiet -- Data/Charts.lua Data/Bundled.lua Data/Sources.lua; then
	echo "Чарт не изменился, выпуск не нужен"
	exit 0
fi
git add Data/Charts.lua Data/Bundled.lua Data/Sources.lua
git commit -q -m "Официальный чарт $(date -u +%Y-%m-%d)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin HEAD
echo "Выпуск: v$(tr -d ' \n' < VERSION).$(date -u +%Y%m%d) (тег поставит GitHub Actions)"

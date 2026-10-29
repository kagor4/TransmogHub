#!/bin/sh
# Ежедневный выпуск каталога и чарта WoW Forever (в ветке forever).
#   tools/charts/release-forever.sh <путь к snapshots/TransmogHub-forever.lua.gz> [папка secrets]
# Собирает Data/ChartsForever.lua и Data/BundledForever.lua тем же сборщиком, что и
# чарт основной игры (в режиме Forever), прогоняет тесты, коммитит в forever и пушит.
# Пуш сам запускает .github/workflows/forever-release.yml (выпуск на GitHub и CurseForge).
set -e
cd "$(dirname "$0")/../.."
SNAP="$1"
SECRETS="$2"
[ -f "$SNAP" ] || { echo "нет снимка Forever: $SNAP"; exit 1; }
[ "$(git rev-parse --abbrev-ref HEAD)" = "forever" ] || { echo "запускать в ветке forever"; exit 1; }
TMP="$(mktemp -d)"
gunzip -c "$SNAP" > "$TMP/sv.lua"
# сборщик пишет и читает глобальные имена основной игры — переименовываем туда и обратно
if [ -f Data/ChartsForever.lua ]; then
	sed 's/^TransmogHub_ChartsForever = /TransmogHub_Charts = /' Data/ChartsForever.lua > "$TMP/charts.lua"
fi
TH_FOREVER=1 lua5.1 tools/charts/build.lua . "$TMP/sv.lua" "$TMP/charts.lua" "" "$SECRETS" "$TMP/bundled.lua" "" ""
sed 's/^TransmogHub_Charts = /TransmogHub_ChartsForever = /' "$TMP/charts.lua" > Data/ChartsForever.lua
sed 's/^TransmogHub_Bundled = /TransmogHub_BundledForever = /' "$TMP/bundled.lua" > Data/BundledForever.lua
rm -rf "$TMP"
luac5.1 -p *.lua Data/*.lua Locales/*.lua
for t in smoke filter locales charts forever; do lua5.1 tests/$t.lua . > /dev/null; done
if git diff --quiet -- Data/ChartsForever.lua Data/BundledForever.lua; then
	echo "Чарт Forever не изменился, выпуск не нужен"
	exit 0
fi
git add Data/ChartsForever.lua Data/BundledForever.lua
git commit -q -m "Официальный чарт Forever $(date -u +%Y-%m-%d)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git push origin HEAD
echo "Выпуск Forever запустится сам (forever-release.yml)"

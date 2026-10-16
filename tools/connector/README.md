# Коннектор модератора

Скрипт для ПК модератора. Забирает журнал жалоб и решения модератора из сохранённых
данных аддона и выгружает их в **закрытый** репозиторий GitHub, где их разбирает
ежедневная проверка (см. [docs/MODERATION.md](../../docs/MODERATION.md)).
Игрокам его ставить не нужно.

## Что нужно

- Windows и **PowerShell 7** (`pwsh`): https://aka.ms/powershell — скрипт сохранён в UTF-8,
  старый Windows PowerShell 5.1 может исказить русские сообщения.
- Закрытый репозиторий для жалоб, например `kagor4/TransmogHub-reports`.
- Токен GitHub **fine-grained**: https://github.com/settings/personal-access-tokens/new
  - Repository access: **Only select repositories** → только репозиторий для жалоб;
  - Permissions → Repository permissions → **Contents: Read and write**;
  - срок действия — на ваш выбор (например, год).

## Установка

1. Скачайте папку `tools/connector` из репозитория, например в `C:\TransmogHubConnector`.
2. Откройте **PowerShell 7** в этой папке и выполните:

   ```powershell
   .\TransmogHubConnector.ps1 -Setup
   ```

   Скрипт спросит папку WoW (например `E:\World of Warcraft`), репозиторий и токен.
   Токен шифруется средствами Windows и хранится в `%APPDATA%\TransmogHubConnector`.

3. Проверьте выгрузку вручную:

   ```powershell
   .\TransmogHubConnector.ps1
   ```

   В репозитории появятся `reports/reports.tsv`, `reports/decisions.tsv`, а когда будут данные —
   `reports/tags.tsv` и `reports/tag-usage.tsv`.

4. Добавьте в планировщик (каждые 6 часов и при входе в Windows):

   ```powershell
   .\TransmogHubConnector.ps1 -Install
   ```

Убрать из планировщика: `.\TransmogHubConnector.ps1 -Uninstall`.
Журнал работы: `%APPDATA%\TransmogHubConnector\connector.log`.

Если PowerShell не даёт запустить скрипт, разрешите локальные скрипты для текущего пользователя:
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Формат файлов

`reports/reports.tsv` — одна жалоба на строку, поля через `|`:
`1|id образа|кто пожаловался|причина (a — реклама, o — оскорбление, x — другое)|время|автор|название|описание`

`reports/decisions.tsv` — решения модератора из вкладки «Модерация»:
`1|действие|цель|время`, где действие: `s` — заблокировать образ, `a` — автора,
`u` / `v` — разблокировать образ / автора, `d` — жалобы необоснованны.

`reports/tags.tsv` — предложенные игроками теги: `1|тег|кто предложил|время`.

`reports/tag-usage.tsv` — раз в день, сколько образов с каждым тегом:
`1|дата|всего образов|ключ=число,ключ=число,…`

`reports/appeals.tsv` — обращения игроков, оспаривающих решения: `1|кто|время|[что оспаривается] текст`.

`reports/ideas.tsv` — предложения игроков: `1|кто|время|вид|текст`, вид: i — идея, b — ошибка, o — другое.

Строки только добавляются: повторная выгрузка не создаёт дублей и не стирает старое.

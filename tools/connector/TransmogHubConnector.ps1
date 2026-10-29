<#
  Transmog Hub — коннектор модератора.

  Читает журнал жалоб, решения модератора, предложения тегов, статистику и снимок базы (для официального чарта) из сохранённых данных аддона
  (WTF\Account\*\SavedVariables\TransmogHub.lua) и выгружает их в закрытый
  репозиторий GitHub. Нужен только модератору; игрокам ставить не нужно.

  Запуск:
    .\TransmogHubConnector.ps1 -Setup     # один раз: путь к WoW, репозиторий, токен
    .\TransmogHubConnector.ps1 -Install   # добавить в планировщик (каждые 6 часов и при входе)
    .\TransmogHubConnector.ps1            # выгрузить сейчас
    .\TransmogHubConnector.ps1 -Uninstall # убрать из планировщика

  Токен хранится зашифрованным средствами Windows (DPAPI): расшифровать его
  можно только под этой же учётной записью Windows.
#>
param(
    [switch]$Setup,
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$ConfigDir = Join-Path $env:APPDATA "TransmogHubConnector"
$ConfigFile = Join-Path $ConfigDir "config.json"
$LogFile = Join-Path $ConfigDir "connector.log"
$TaskName = "TransmogHubConnector"

function Write-Log($message) {
    $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $message
    Write-Host $line
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

function Read-Config {
    if (-not (Test-Path $ConfigFile)) {
        throw "Нет настроек. Запустите: .\TransmogHubConnector.ps1 -Setup"
    }
    $config = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
    $secure = ConvertTo-SecureString $config.Token
    $config.Token = [System.Net.NetworkCredential]::new("", $secure).Password
    return $config
}

function Invoke-Setup {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
    $default = "C:\Program Files (x86)\World of Warcraft"
    $wow = Read-Host "Папка World of Warcraft (Enter = $default)"
    if ([string]::IsNullOrWhiteSpace($wow)) { $wow = $default }
    if (-not (Test-Path (Join-Path $wow "_retail_\WTF"))) {
        throw "Не нашёл $wow\_retail_\WTF. Проверьте путь, например E:\World of Warcraft"
    }
    $repo = Read-Host "Закрытый репозиторий для жалоб (например kagor4/TransmogHub-reports)"
    $token = Read-Host "Токен GitHub (fine-grained, доступ Contents: Read and write только к этому репозиторию)" -AsSecureString
    $config = [ordered]@{
        WowPath = $wow
        Repo    = $repo.Trim()
        Token   = ConvertFrom-SecureString $token
    }
    $config | ConvertTo-Json | Set-Content -Path $ConfigFile -Encoding UTF8
    Write-Log "Настройки сохранены в $ConfigFile"
}

function Invoke-Install {
    $script = $PSCommandPath
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $every6h = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Hours 6)
    $atLogon = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($every6h, $atLogon) `
        -Description "Выгрузка жалоб Transmog Hub на GitHub" -Force | Out-Null
    Write-Log "Задача '$TaskName' добавлена в планировщик: каждые 6 часов и при входе в Windows"
}

# Строки массива из SavedVariables: ["имя"] = { "строка", -- [1] ... }
function Get-SavedArray($text, $key) {
    $result = @()
    $pattern = '\["' + [regex]::Escape($key) + '"\]\s*=\s*\{(.*?)\n\s*\},'
    $match = [regex]::Match($text, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) { return $result }
    foreach ($m in [regex]::Matches($match.Groups[1].Value, '"((?:[^"\\]|\\.)*)"')) {
        $value = $m.Groups[1].Value -replace '\\"', '"' -replace '\\\\', '\'
        if ($value.StartsWith("1|")) { $result += $value }
    }
    return $result
}

function Get-RemoteFile($config, $path) {
    $headers = @{ Authorization = "Bearer $($config.Token)"; "User-Agent" = "TransmogHubConnector"; Accept = "application/vnd.github+json" }
    $uri = "https://api.github.com/repos/$($config.Repo)/contents/$path"
    try {
        $file = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        $bytes = [Convert]::FromBase64String(($file.content -replace "\s", ""))
        return @{ Sha = $file.sha; Lines = ([System.Text.Encoding]::UTF8.GetString($bytes) -split "`n" | Where-Object { $_ -ne "" }) }
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return @{ Sha = $null; Lines = @() } }
        throw
    }
}

function Set-RemoteFile($config, $path, $sha, $lines, $message) {
    $headers = @{ Authorization = "Bearer $($config.Token)"; "User-Agent" = "TransmogHubConnector"; Accept = "application/vnd.github+json" }
    $uri = "https://api.github.com/repos/$($config.Repo)/contents/$path"
    $content = ($lines -join "`n") + "`n"
    $body = @{ message = $message; content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($content)) }
    if ($sha) { $body.sha = $sha }
    Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -ContentType "application/json; charset=utf-8" | Out-Null
}

# Добавить новые строки к файлу в репозитории (старые не теряются)
function Sync-File($config, $path, $localLines, $what) {
    $remote = Get-RemoteFile $config $path
    $known = @{}
    foreach ($line in $remote.Lines) { $known[$line] = $true }
    $new = @($localLines | Where-Object { -not $known.ContainsKey($_) } | Select-Object -Unique)
    if ($new.Count -eq 0) {
        Write-Log "$what - нового нет"
        return
    }
    Set-RemoteFile $config $path $remote.Sha (@($remote.Lines) + $new) "Новые $what - $($new.Count)"
    Write-Log "$what - выгружено новых: $($new.Count)"
}

# Снимок всей базы модератора для официального чарта: сжатый файл целиком
# (snapshots/TransmogHub.lua.gz). Ежедневная проверка считает по нему чарт.
# База персонажа в Америке (сеть там своя) — отдельно, snapshots/TransmogHub-us.lua.gz:
# её образы попадают в общий каталог.
function Sync-Snapshot($config, $file, $path = "snapshots/TransmogHub.lua.gz") {
    $headers = @{ Authorization = "Bearer $($config.Token)"; "User-Agent" = "TransmogHubConnector"; Accept = "application/vnd.github+json" }
    $uri = "https://api.github.com/repos/$($config.Repo)/contents/$path"
    $sha = $null
    try { $sha = (Invoke-RestMethod -Uri $uri -Headers $headers -Method Get).sha } catch {
        if (-not ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404)) { throw }
    }
    $raw = [System.IO.File]::ReadAllBytes($file.FullName)
    $buffer = New-Object System.IO.MemoryStream
    $gzip = New-Object System.IO.Compression.GZipStream($buffer, [System.IO.Compression.CompressionMode]::Compress)
    $gzip.Write($raw, 0, $raw.Length)
    $gzip.Close()
    $body = @{ message = "Снимок базы для чарта"; content = [Convert]::ToBase64String($buffer.ToArray()) }
    if ($sha) { $body.sha = $sha }
    Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body ($body | ConvertTo-Json) -ContentType "application/json; charset=utf-8" | Out-Null
    Write-Log ("снимок базы выгружен: {0} ({1:N0} КБ)" -f $path, ($raw.Length / 1KB))
}

function Invoke-Sync {
    $config = Read-Config
    $files = Get-ChildItem -Path (Join-Path $config.WowPath "_retail_\WTF\Account\*\SavedVariables\TransmogHub.lua") -ErrorAction SilentlyContinue
    if (-not $files) {
        Write-Log "Файлы TransmogHub.lua не найдены. Зайдите в игру персонажем-модератором хотя бы раз."
        return
    }
    $reports = @(); $decisions = @(); $tags = @(); $tagStats = @(); $appeals = @(); $ideas = @(); $stats = @(); $usage = @(); $usageNames = @()
    $snapshot = $null; $snapshotUs = $null
    foreach ($file in $files) {
        $text = Get-Content $file.FullName -Raw -Encoding UTF8
        # регион игры, который аддон записывает при входе: 1 — Америка, 3 — Европа
        $region = 0
        if ($text -match '\["region"\]\s*=\s*(\d+)') { $region = [int]$Matches[1] }
        $isModerator = $text -match '\["moderator"\]\s*=\s*true'
        # для чарта — свежайший файл аккаунта модератора. В нём базы всех регионов этой
        # учётной записи Battle.net (аддон хранит их по регионам), сборка их разделит
        if ($isModerator) {
            if (-not $snapshot -or $file.LastWriteTime -gt $snapshot.LastWriteTime) { $snapshot = $file }
        }
        elseif ($region -eq 1) {
            # отдельная учётная запись в Америке без модератора — свежайший файл
            if (-not $snapshotUs -or $file.LastWriteTime -gt $snapshotUs.LastWriteTime) { $snapshotUs = $file }
        }
        $reports += Get-SavedArray $text "modLog"
        $decisions += Get-SavedArray $text "modDecisions"
        $tags += Get-SavedArray $text "modTags"
        $tagStats += Get-SavedArray $text "modTagStats"
        $appeals += Get-SavedArray $text "modAppeals"
        $ideas += Get-SavedArray $text "modIdeas"
        $stats += Get-SavedArray $text "modStats"
        $usage += Get-SavedArray $text "modUsage"
        $usageNames += Get-SavedArray $text "modUsageNames"
    }
    Sync-File $config "reports/reports.tsv" $reports "жалобы"
    Sync-File $config "reports/decisions.tsv" $decisions "решения"
    Sync-File $config "reports/tags.tsv" $tags "предложения тегов"
    Sync-File $config "reports/tag-usage.tsv" $tagStats "статистика тегов"
    Sync-File $config "reports/appeals.tsv" $appeals "обращения"
    Sync-File $config "reports/ideas.tsv" $ideas "предложения"
    Sync-File $config "reports/usage.tsv" $usage "статистика нажатий"
    Sync-File $config "reports/usage-names.tsv" $usageNames "названия кнопок"
    # снимков много, поэтому файл на каждый месяц: reports/stats/2026-10.tsv
    foreach ($month in ($stats | ForEach-Object { $_.Substring(4, 7) } | Sort-Object -Unique)) {
        Sync-File $config "reports/stats/$month.tsv" @($stats | Where-Object { $_.Substring(4, 7) -eq $month }) "статистика рейтингов $month"
    }
    if ($snapshot) { Sync-Snapshot $config $snapshot } else { Write-Log "снимок базы - нет файла модератора" }
    if ($snapshotUs) { Sync-Snapshot $config $snapshotUs "snapshots/TransmogHub-us.lua.gz" }
    # WoW Forever (клиент _forever_): своя сеть, свой каталог и чарт — свежайший файл
    # аддона из папки Forever, snapshots/TransmogHub-forever.lua.gz
    $forever = Get-ChildItem -Path (Join-Path $config.WowPath "_forever_\WTF\Account\*\SavedVariables\TransmogHub.lua") -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($forever) { Sync-Snapshot $config $forever "snapshots/TransmogHub-forever.lua.gz" }
}

try {
    if ($Setup) { Invoke-Setup }
    elseif ($Install) { Invoke-Install }
    elseif ($Uninstall) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Log "Задача '$TaskName' удалена из планировщика"
    }
    else { Invoke-Sync }
} catch {
    Write-Log "Ошибка: $($_.Exception.Message)"
    exit 1
}

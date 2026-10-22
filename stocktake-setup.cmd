@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8); $i=$t.IndexOf('#PS'+'-START'); Invoke-Expression $t.Substring($i)"
exit /b
#PS-START
# ===== 天掌 盤點檢查：輸入安裝碼解開程式（build_locked.py 產生，不要手改） =====
$Locked = @{ s = 'VtNU3ExNrPrnG4dcYasIiw=='; i = 'u0nsI2nL1rDrKOfGun5yKA=='; c = 'elDfJjbdUFAdtHK3v8l5qI06Zw8wg1Slq4YQ7SNKJvM08+Wux57LXrKWOI7LDrWNFyBV6uEIAryf7WH+xtNTAR73CXgcrGJcjZbkWpRh1g4w78yDYHKdWPio6fdFqZUdW1XLnmV9f2s9iASN3TVqow=='; t = 'Kj9EsOmGbj6KSfjk4HukAgvozIpNaJAFC88GHQF68dQ='; n = 200000 }
function Unlock-Payload([string]$code) {
    $kdf = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($code, [Convert]::FromBase64String($Locked.s), [int]$Locked.n)
    $key = $kdf.GetBytes(32); $mk = $kdf.GetBytes(32)
    $iv = [Convert]::FromBase64String($Locked.i); $ct = [Convert]::FromBase64String($Locked.c)
    $h = New-Object System.Security.Cryptography.HMACSHA256(,$mk)
    $calc = [Convert]::ToBase64String($h.ComputeHash([byte[]]($iv + $ct)))
    if ($calc -ne $Locked.t) { return $null }
    $aes = [System.Security.Cryptography.Aes]::Create(); $aes.Key = $key; $aes.IV = $iv
    $gz = $aes.CreateDecryptor().TransformFinalBlock($ct, 0, $ct.Length)
    $ms = New-Object System.IO.MemoryStream(,$gz); $zs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object System.IO.StreamReader($zs, [System.Text.Encoding]::UTF8); $json = $sr.ReadToEnd(); $sr.Close()
    return ($json | ConvertFrom-Json)
}
Write-Host ''
Write-Host '  天掌 盤點檢查 安裝' -ForegroundColor Green
Write-Host '  這個安裝檔要「安裝碼」才能裝，請向老闆要（10 個英文和數字，大小寫都可以）。' -ForegroundColor Gray
Write-Host ''
$Secret = $null
for ($try = 1; $try -le 5 -and -not $Secret; $try++) {
    $code = ((Read-Host '  請輸入安裝碼') -replace '[\s-]', '').ToUpper()
    if (-not $code) { continue }
    Write-Host '  檢查中…' -ForegroundColor Gray
    try { $Secret = Unlock-Payload $code } catch { $Secret = $null }
    if (-not $Secret) { Write-Host ('  安裝碼不對（第 ' + $try + ' 次）。請再確認一次。') -ForegroundColor Yellow }
}
if (-not $Secret) { Write-Host ''; Write-Host '  安裝碼不對，沒有安裝。請向老闆確認安裝碼。' -ForegroundColor Red; Read-Host '  按 Enter 關閉'; exit }
$Payload = [ordered]@{}
foreach ($pr in $Secret.files.PSObject.Properties) { $Payload[$pr.Name] = [string]$pr.Value }
$NasLogin = @{ h = [string]$Secret.nas.h; u = [string]$Secret.nas.u; p = [string]$Secret.nas.p }
$Secret = $null
# 程式從 NAS 抓（永遠是最新版）：先存 NAS 登入（這台已經有就沿用），再讀 tool.json 列的檔案
Write-Host '  安裝碼正確，正在從公司 NAS 抓程式…' -ForegroundColor Green
$have = ((cmdkey /list:$($NasLogin.h) 2>&1 | Out-String) -match 'target=')
if (-not $have) {
    $nu = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($NasLogin.u)); $np = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($NasLogin.p))
    cmdkey /add:$($NasLogin.h) /user:$nu /pass:$np | Out-Null; $nu = $null; $np = $null
}
$src = '\\192.168.123.95\share\07_IT設備與系統\ERP小幫手\手機盤點\天掌盤點檢查'
$job = Start-Job -ScriptBlock { param($s) $t = Join-Path $s 'tool.json'; if (Test-Path -LiteralPath $t) { [System.IO.File]::ReadAllText($t, [System.Text.Encoding]::UTF8) } } -ArgumentList $src
$tj = $null; if (Wait-Job $job -Timeout 20) { try { $tj = Receive-Job $job } catch {} }; Remove-Job $job -Force -ErrorAction SilentlyContinue
if (-not $tj) { Write-Host ''; Write-Host '  連不到公司 NAS（192.168.123.95），沒有安裝。請確認這台電腦連得上公司網路（在公司外面要先連 VPN），再雙擊一次。' -ForegroundColor Red; Read-Host '  按 Enter 關閉'; exit }
foreach ($f in @(($tj | ConvertFrom-Json).files)) {
    $p = Join-Path $src $f
    if (-not (Test-Path -LiteralPath $p)) { Write-Host ('  NAS 上少了 ' + $f + '，沒有安裝，請拍給 Claude。') -ForegroundColor Red; Read-Host '  按 Enter 關閉'; exit }
    $Payload[$f] = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($p))
}
Write-Host ('  抓到 ' + $Payload.Count + ' 個檔案') -ForegroundColor Gray
# ===== 天掌 盤點檢查 安裝（程式都包在這個檔案裡，不需要先連 NAS） =====
# 這段由「小工具打包\build_installer.py」產生，不要手改；要改請改 install_template.ps1 再重新打包
$ErrorActionPreference = 'Stop'
function Say([string]$m, [string]$c = 'Gray') { Write-Host ('  ' + $m) -ForegroundColor $c }
Write-Host ''
Say '天掌 盤點檢查 安裝' 'Green'
Write-Host ''
try {
    $App = Join-Path $env:LOCALAPPDATA 'Tanjun-Stocktake\app'
    New-Item -ItemType Directory -Force -Path $App | Out-Null
    # 舊版在跑的話先關掉，不然新程式不會生效
    if (8731 -gt 0) {
        try {
            Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'http://127.0.0.1:8731/api/shutdown' -Body '' -TimeoutSec 3 | Out-Null
            Start-Sleep -Milliseconds 800
            Say '已關掉舊版'
        } catch {}
    }
    foreach ($k in $Payload.Keys) {
        [System.IO.File]::WriteAllBytes((Join-Path $App $k), [Convert]::FromBase64String($Payload[$k]))
    }
    $nas = '\\192.168.123.95\share\07_IT設備與系統\ERP小幫手\手機盤點\天掌盤點檢查'
    [System.IO.File]::WriteAllText((Join-Path $App 'source.txt'), $nas, (New-Object System.Text.UTF8Encoding($false)))
    Say ('已安裝到：' + $App)

    # NAS 登入：這台電腦還沒存過 NAS 帳密才存（已有就沿用，不蓋掉別人的）
    if ($NasLogin) {
        $nasHost = $NasLogin.h
        $have = ((cmdkey /list:$nasHost 2>&1 | Out-String) -match 'target=')
        if (-not $have) {
            $nu = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($NasLogin.u))
            $np = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($NasLogin.p))
            cmdkey /add:$nasHost /user:$nu /pass:$np | Out-Null
            Say '已設定 NAS 登入'
        } else {
            Say '這台電腦已經有 NAS 登入，沿用'
        }
    }
    $job = Start-Job -ScriptBlock { param($p) Test-Path -LiteralPath (Join-Path $p 'version.txt') } -ArgumentList $nas
    $ok = $false
    if (Wait-Job $job -Timeout 8) { try { $ok = [bool](Receive-Job $job) } catch {} }
    Remove-Job $job -Force -ErrorAction SilentlyContinue
    if ($ok) { Say '連得到 NAS，之後會自動更新' 'Green' }
    else { Say '注意：讀不到 NAS，程式可以用，但不會自動更新。請把這個畫面拍給 Claude。' 'Yellow' }

    # 捷徑（桌面＋開始功能表「天掌五金」）
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Desktop'), (Join-Path ([Environment]::GetFolderPath('Programs')) '天掌五金'))) {
        if (-not $dir) { continue }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $lnk = $ws.CreateShortcut((Join-Path $dir '天掌 盤點檢查.lnk'))
        $lnk.TargetPath = Join-Path $env:WINDIR 'System32\wscript.exe'
        $lnk.Arguments = '"' + (Join-Path $App 'Start.vbs') + '"'
        $lnk.WorkingDirectory = $App
        $lnk.IconLocation = (Join-Path $env:WINDIR 'System32\shell32.dll') + ',22'
        $lnk.Description = '手機盤點送出後：算掃描當下帳面差異、查原因、開 A113 盤點異動單'
        $lnk.Save()
    }
    Say '已建立桌面捷徑「天掌 盤點檢查」'
    Write-Host ''
    Say '安裝完成，正在打開…' 'Green'
    Start-Process -FilePath (Join-Path $env:WINDIR 'System32\wscript.exe') -ArgumentList ('"' + (Join-Path $App 'Start.vbs') + '"')
    Start-Sleep -Seconds 4
}
catch {
    Write-Host ''
    Say ('安裝失敗：' + $_.Exception.Message) 'Red'
    Write-Host ''
    Read-Host '  按 Enter 關閉'
}

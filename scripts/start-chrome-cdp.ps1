# Launch Chrome with CDP for CowAgent browser + web-access skill
$chrome = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
    $chrome = "C:\Program Files\Google\Chrome\Application\chrome.exe"
}
$profile = "$env:USERPROFILE\.cow\chrome-cdp"
if (-not (Test-Path $chrome)) {
    Write-Error "Chrome not found. Install Google Chrome first."
    exit 1
}
$existing = netstat -ano | Select-String ":9222\s+.*LISTENING"
if ($existing) {
    Write-Host "Chrome CDP already listening on port 9222"
    exit 0
}
Start-Process $chrome -ArgumentList "--remote-debugging-port=9222", "--user-data-dir=$profile", "about:blank"
Write-Host "Chrome CDP started on http://localhost:9222 (profile: $profile)"

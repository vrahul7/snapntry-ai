# PowerShell Script to serve the APK locally for phone installation

# Find active Wi-Fi or Ethernet IPv4 address
$ipAddresses = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and 
    $_.IPAddress -notlike "169.254.*" -and 
    $_.InterfaceAlias -notlike "*Loopback*" -and
    $_.InterfaceAlias -notlike "*vEthernet*"
}

$ip = $ipAddresses[0].IPAddress

if (-not $ip) {
    # Fallback to any non-loopback IP
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike "127.*" } | Select-Object -First 1).IPAddress
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "        B2B GenA2Z APK Local Server Installer" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "This script lets you easily download the compiled APK to your phone over Wi-Fi."
Write-Host ""
Write-Host "Instructions:"
Write-Host "1. Connect your Android phone to the SAME Wi-Fi network as this PC."
Write-Host "2. Open your phone's browser and go to:"
Write-Host "   http://$($ip):8000/app-release.apk" -ForegroundColor Yellow
Write-Host "3. Tap to download and install!"
Write-Host "=========================================================="

# Check if python is installed
$pythonInstalled = $false
try {
    $null = python --version 2>&1
    $pythonInstalled = $true
} catch {}

$apkDir = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk"

if (-not (Test-Path $apkDir)) {
    Write-Host "Error: APK directory not found. Please build the APK first." -ForegroundColor Red
    exit
}

Set-Location $apkDir

if ($pythonInstalled) {
    Write-Host "Starting Python HTTP Server on Port 8000..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the server when done."
    python -m http.server 8000
} else {
    Write-Host "Python was not found on your system." -ForegroundColor Yellow
    Write-Host "Running a simple PowerShell HTTP listener..." -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop the listener when done."
    
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://*:8000/")
    try {
        $listener.Start()
    } catch {
        Write-Host "Failed to start HTTP listener on port 8000: $_" -ForegroundColor Red
        Write-Host "Make sure you run this script as Administrator or close other applications on port 8000."
        exit
    }
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        $urlPath = $request.Url.LocalPath
        if ($urlPath -eq "/app-release.apk") {
            $filePath = Join-Path $apkDir "app-release.apk"
            if (Test-Path $filePath) {
                Write-Host "Sending APK download to $($request.RemoteEndPoint)..." -ForegroundColor Green
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentType = "application/vnd.android.package-archive"
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
            }
        } else {
            $response.StatusCode = 200
            $html = "<html><body><h1>B2B GenA2Z APK Server</h1><p><a href='/app-release.apk'>Click here to download app-release.apk</a></p></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $response.OutputStream.Close()
    }
}

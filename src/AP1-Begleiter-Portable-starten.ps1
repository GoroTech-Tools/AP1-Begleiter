# AP1-Begleiter-Portable Startskript (GUI)
#
# Optimierungen gegenüber der alten Version:
# - Kein rekursiver Selbstaufruf des Skripts
# - Robuste Fensterermittlung über den konkreten Prozess statt globaler Prozessliste
# - Fehlerbehandlung für Browser-Start und URL-Eingaben
# - Einfache GUI zur Pflege der URLs und zum Starten
# - Profile, Persistenz (JSON) und Diagnosemodus

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class WinAPI {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
"@ -Language CSharp

$script:DefaultProfiles = [ordered]@{
    "Standard" = @{
        Url1 = "https://share.eu.articulate.com/aDHiswIhkQ5QP2-VZR9Qy"
        Url2 = "https://share.eu.articulate.com/R-XBM_yDnkWKgzzDy1gAm"
    }
}

if (-not $script:AppVersion -or [string]::IsNullOrWhiteSpace([string]$script:AppVersion)) {
    $script:AppVersion = "v1.0.4"
}

function Get-SettingsPath {
    $baseDir = Join-Path -Path $env:APPDATA -ChildPath "AP1-Begleiter-Portable"
    if (-not (Test-Path -Path $baseDir -PathType Container)) {
        New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
    }

    return Join-Path -Path $baseDir -ChildPath "settings.json"
}

function Get-DefaultSettings {
    return [ordered]@{
        ArrangeWindows = $true
    }
}

function Import-Settings {
    $path = Get-SettingsPath
    $defaults = Get-DefaultSettings

    if (-not (Test-Path -Path $path -PathType Leaf)) {
        return [PSCustomObject]$defaults
    }

    try {
        $raw = Get-Content -Path $path -Encoding UTF8 -Raw
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return [PSCustomObject]$defaults
        }

        $loaded = $raw | ConvertFrom-Json
        return [PSCustomObject]@{
            ArrangeWindows = if ($null -ne $loaded.ArrangeWindows) { [bool]$loaded.ArrangeWindows } else { $defaults.ArrangeWindows }
        }
    }
    catch {
        return [PSCustomObject]$defaults
    }
}

function Save-Settings {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Settings
    )

    $path = Get-SettingsPath
    $json = $Settings | ConvertTo-Json -Depth 5
    Set-Content -Path $path -Value $json -Encoding UTF8
}

function Test-ValidUrl {
    param([string]$Url)

    $uri = $null
    return [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)
}

function Wait-MainWindowHandle {
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Process]$Process,

        [int]$TimeoutMs = 12000
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        try {
            $Process.Refresh()
            if ($Process.MainWindowHandle -and $Process.MainWindowHandle -ne [IntPtr]::Zero) {
                return $Process.MainWindowHandle
            }
        } catch {
            # Prozess kann beendet worden sein
            break
        }

        Start-Sleep -Milliseconds 150
    }

    return [IntPtr]::Zero
}

function Set-WindowHalf {
    param(
        [Parameter(Mandatory)]
        [IntPtr]$Handle,

        [Parameter(Mandatory)]
        [ValidateSet("Left", "Right")]
        [string]$Side
    )

    $workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $halfWidth = [Math]::Floor($workArea.Width / 2)

    if ($Side -eq "Left") {
        $x = $workArea.Left
        $width = $halfWidth
    } else {
        $x = $workArea.Left + $halfWidth
        $width = $workArea.Width - $halfWidth
    }

    [void][WinAPI]::ShowWindow($Handle, 9) # SW_RESTORE
    [void][WinAPI]::MoveWindow($Handle, $x, $workArea.Top, $width, $workArea.Height, $true)
    [void][WinAPI]::SetForegroundWindow($Handle)
}

function Get-WindowRectangle {
    param([Parameter(Mandatory)][IntPtr]$Handle)

    $rect = New-Object WinAPI+RECT
    $ok = [WinAPI]::GetWindowRect($Handle, [ref]$rect)
    if (-not $ok) {
        return $null
    }

    return [PSCustomObject]@{
        Left = $rect.Left
        Top = $rect.Top
        Right = $rect.Right
        Bottom = $rect.Bottom
        Width = ($rect.Right - $rect.Left)
        Height = ($rect.Bottom - $rect.Top)
    }
}

function Set-WindowHalfReliable {
    param(
        [Parameter(Mandatory)][IntPtr]$Handle,
        [Parameter(Mandatory)][ValidateSet("Left", "Right")][string]$Side,
        [int]$MaxAttempts = 6
    )

    $layout = Get-WindowLayout
    $target = if ($Side -eq "Left") { $layout.Left } else { $layout.Right }

    for ($i = 1; $i -le $MaxAttempts; $i++) {
        Set-WindowHalf -Handle $Handle -Side $Side
        Start-Sleep -Milliseconds 150

        $rect = Get-WindowRectangle -Handle $Handle
        if (-not $rect) {
            continue
        }

        $leftOk = [Math]::Abs($rect.Left - $target.X) -le 24
        $topOk = [Math]::Abs($rect.Top - $target.Y) -le 24
        $widthOk = [Math]::Abs($rect.Width - $target.Width) -le 64

        if ($leftOk -and $topOk -and $widthOk) {
            return $true
        }
    }

    return $false
}

function Get-WindowLayout {
    $workArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $halfWidth = [Math]::Floor($workArea.Width / 2)

    return @{
        Left = @{
            X = $workArea.Left
            Y = $workArea.Top
            Width = $halfWidth
            Height = $workArea.Height
        }
        Right = @{
            X = $workArea.Left + $halfWidth
            Y = $workArea.Top
            Width = $workArea.Width - $halfWidth
            Height = $workArea.Height
        }
    }
}

function Resolve-EdgeExecutable {
    # 1) Über PATH / App Execution Aliases
    $cmd = Get-Command "msedge.exe" -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
        return $cmd.Source
    }

    # 2) Über App Paths (Registry)
    $regCandidates = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe"
    )

    foreach ($regPath in $regCandidates) {
        try {
            $value = (Get-ItemProperty -Path $regPath -ErrorAction Stop).'(default)'
            if ($value -and (Test-Path -LiteralPath $value)) {
                return $value
            }
        }
        catch {
            # ignorieren und weiter prüfen
        }
    }

    # 3) Typische Installationspfade
    $pathCandidates = @(
        (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path -Path $env:ProgramFiles -ChildPath "Microsoft\Edge\Application\msedge.exe"),
        (Join-Path -Path $env:LocalAppData -ChildPath "Microsoft\Edge\Application\msedge.exe")
    )

    foreach ($candidate in $pathCandidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    return $null
}

function Start-EdgeWindow {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$EdgePath
    )

    if (-not (Test-ValidUrl -Url $Url)) {
        throw "Ungültige URL: $Url"
    }

    $arguments = @("--new-window", $Url)

    return Start-Process -FilePath $EdgePath -ArgumentList $arguments -PassThru -ErrorAction Stop
}

function Get-EdgeMainWindows {
    $windows = Get-Process -Name "msedge" -ErrorAction SilentlyContinue |
        ForEach-Object {
            try {
                $_.Refresh()
                if ($_.MainWindowHandle -and $_.MainWindowHandle -ne [IntPtr]::Zero) {
                    [PSCustomObject]@{
                        StartTime = $_.StartTime
                        Handle = $_.MainWindowHandle
                        ProcessId = $_.Id
                    }
                }
            }
            catch {
                # Prozess ggf. schon beendet oder nicht zugreifbar
            }
        }

    if (-not $windows) {
        return @()
    }

    # Doppelte Handles entfernen
    return @(
        $windows |
            Sort-Object -Property StartTime |
            Group-Object -Property Handle |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    )
}

function Get-NewEdgeMainWindowHandle {
    param(
        [Int64[]]$BeforeHandles,
        [int]$TimeoutMs = 10000
    )

    $beforeSet = New-Object System.Collections.Generic.HashSet[Int64]
    foreach ($h in ($BeforeHandles | Where-Object { $_ })) {
        [void]$beforeSet.Add([Int64]$h)
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $current = Get-EdgeMainWindows

        $newWindows = @(
            $current |
                Where-Object { -not $beforeSet.Contains([Int64]$_.Handle) } |
                Sort-Object -Property StartTime
        )

        if ($newWindows.Count -ge 1) {
            return [IntPtr]$newWindows[0].Handle
        }

        Start-Sleep -Milliseconds 200
    }

    return [IntPtr]::Zero
}

function Set-EdgeWindowsPrimarySplit {
    param(
        [Parameter(Mandatory)][IntPtr]$LeftHandle,
        [Parameter(Mandatory)][IntPtr]$RightHandle
    )

    if ($LeftHandle -eq [IntPtr]::Zero -or $RightHandle -eq [IntPtr]::Zero) {
        return $false
    }

    # Mehrere Runden, damit auch verzögertes Edge-UI zuverlässig trifft.
    $okLeft = $false
    $okRight = $false

    foreach ($delay in @(0, 700, 1500)) {
        if ($delay -gt 0) {
            Start-Sleep -Milliseconds $delay
        }

        $okLeft = Set-WindowHalfReliable -Handle $LeftHandle -Side Left
        $okRight = Set-WindowHalfReliable -Handle $RightHandle -Side Right

        if ($okLeft -and $okRight) {
            return $true
        }
    }

    return ($okLeft -and $okRight)
}

function Start-UrlInDefaultBrowser {
    param([Parameter(Mandatory)][string]$Url)

    if (-not (Test-ValidUrl -Url $Url)) {
        throw "Ungültige URL: $Url"
    }

    Start-Process -FilePath $Url -ErrorAction Stop | Out-Null
}

function Get-DocumentationPath {
    if ($script:BundledDocPath -and (Test-Path -LiteralPath $script:BundledDocPath -PathType Leaf)) {
        return $script:BundledDocPath
    }

    $candidates = @()

    if ($PSScriptRoot) {
        $candidates += (Join-Path -Path $PSScriptRoot -ChildPath "KURZDOKUMENTATION.txt")
        $candidates += (Join-Path -Path $PSScriptRoot -ChildPath "docs\KURZDOKUMENTATION.txt")
    }

    $candidates += (Join-Path -Path (Get-Location).Path -ChildPath "KURZDOKUMENTATION.txt")
    $candidates += (Join-Path -Path (Get-Location).Path -ChildPath "docs\KURZDOKUMENTATION.txt")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

function Open-Documentation {
    $docPath = Get-DocumentationPath
    if (-not $docPath) {
        throw "Die Kurzdokumentation konnte nicht gefunden werden."
    }

    Start-Process -FilePath $docPath -ErrorAction Stop | Out-Null
}

function Get-AppIconPath {
    if ($script:BundledIconPath -and (Test-Path -LiteralPath $script:BundledIconPath -PathType Leaf)) {
        return $script:BundledIconPath
    }

    $candidates = @()

    if ($PSScriptRoot) {
        $candidates += (Join-Path -Path $PSScriptRoot -ChildPath "app_icon.ico")
        $candidates += (Join-Path -Path $PSScriptRoot -ChildPath "src\app_icon.ico")
    }

    $cwd = (Get-Location).Path
    $candidates += (Join-Path -Path $cwd -ChildPath "app_icon.ico")
    $candidates += (Join-Path -Path $cwd -ChildPath "src\app_icon.ico")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }

    return $null
}

# ------------------------- GUI -------------------------

$form = New-Object System.Windows.Forms.Form
$form.Text = "AP1-Begleiter-Portable starten ($script:AppVersion)"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(760, 330)
$form.MinimumSize = New-Object System.Drawing.Size(760, 330)
$form.MaximizeBox = $false
$form.FormBorderStyle = "FixedDialog"

$iconPath = Get-AppIconPath
if ($iconPath) {
    try {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
    }
    catch {
        # Kein harter Fehler, falls das Icon in einer Umgebung nicht gesetzt werden kann.
    }
}

$lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.Location = New-Object System.Drawing.Point(20, 20)
$lblInfo.Size = New-Object System.Drawing.Size(700, 22)
$lblInfo.Text = "Öffnet zwei Edge-Fenster und ordnet sie links/rechts an."
$form.Controls.Add($lblInfo)

$lblProfile = New-Object System.Windows.Forms.Label
$lblProfile.Location = New-Object System.Drawing.Point(20, 55)
$lblProfile.Size = New-Object System.Drawing.Size(180, 20)
$lblProfile.Text = "Profil:"
$form.Controls.Add($lblProfile)

$cmbProfile = New-Object System.Windows.Forms.ComboBox
$cmbProfile.Location = New-Object System.Drawing.Point(200, 52)
$cmbProfile.Size = New-Object System.Drawing.Size(300, 24)
$cmbProfile.DropDownStyle = "DropDownList"
$cmbProfile.Enabled = $false
$form.Controls.Add($cmbProfile)

$lblUrl1 = New-Object System.Windows.Forms.Label
$lblUrl1.Location = New-Object System.Drawing.Point(20, 90)
$lblUrl1.Size = New-Object System.Drawing.Size(180, 20)
$lblUrl1.Text = "URL 1 (links):"
$form.Controls.Add($lblUrl1)

$txtUrl1 = New-Object System.Windows.Forms.TextBox
$txtUrl1.Location = New-Object System.Drawing.Point(200, 87)
$txtUrl1.Size = New-Object System.Drawing.Size(520, 23)
$txtUrl1.ReadOnly = $true
$txtUrl1.TabStop = $false
$form.Controls.Add($txtUrl1)

$lblUrl2 = New-Object System.Windows.Forms.Label
$lblUrl2.Location = New-Object System.Drawing.Point(20, 125)
$lblUrl2.Size = New-Object System.Drawing.Size(180, 20)
$lblUrl2.Text = "URL 2 (rechts):"
$form.Controls.Add($lblUrl2)

$txtUrl2 = New-Object System.Windows.Forms.TextBox
$txtUrl2.Location = New-Object System.Drawing.Point(200, 122)
$txtUrl2.Size = New-Object System.Drawing.Size(520, 23)
$txtUrl2.ReadOnly = $true
$txtUrl2.TabStop = $false
$form.Controls.Add($txtUrl2)

$chkArrange = New-Object System.Windows.Forms.CheckBox
$chkArrange.Location = New-Object System.Drawing.Point(200, 158)
$chkArrange.Size = New-Object System.Drawing.Size(260, 25)
$chkArrange.Text = "Fenster automatisch links/rechts anordnen"
$form.Controls.Add($chkArrange)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Location = New-Object System.Drawing.Point(200, 196)
$btnStart.Size = New-Object System.Drawing.Size(200, 35)
$btnStart.Text = "Starten"
$form.Controls.Add($btnStart)

$btnDoc = New-Object System.Windows.Forms.Button
$btnDoc.Location = New-Object System.Drawing.Point(420, 196)
$btnDoc.Size = New-Object System.Drawing.Size(120, 35)
$btnDoc.Text = "Dokumentation"
$form.Controls.Add($btnDoc)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Location = New-Object System.Drawing.Point(560, 196)
$btnClose.Size = New-Object System.Drawing.Size(120, 35)
$btnClose.Text = "Schließen"
$form.Controls.Add($btnClose)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(20, 246)
$lblStatus.Size = New-Object System.Drawing.Size(700, 28)
$lblStatus.Text = "Bereit."
$lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
$form.Controls.Add($lblStatus)

$setStatus = {
    param(
        [string]$Text,
        [bool]$IsError = $false
    )

    $lblStatus.Text = $Text
    if ($IsError) {
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkRed
    } else {
        $lblStatus.ForeColor = [System.Drawing.Color]::DarkGreen
    }
}

$saveCurrentSettings = {
    $settings = [PSCustomObject]@{
        ArrangeWindows = $chkArrange.Checked
    }

    Save-Settings -Settings $settings
}

foreach ($profileName in $script:DefaultProfiles.Keys) {
    [void]$cmbProfile.Items.Add($profileName)
}

$loadedSettings = Import-Settings
$txtUrl1.Text = [string]$script:DefaultProfiles["Standard"].Url1
$txtUrl2.Text = [string]$script:DefaultProfiles["Standard"].Url2
$chkArrange.Checked = $loadedSettings.ArrangeWindows
$cmbProfile.SelectedItem = "Standard"

$btnStart.Add_Click({
    & $setStatus "Starte Edge-Fenster ..." $false

    try {
        $url1 = $txtUrl1.Text.Trim()
        $url2 = $txtUrl2.Text.Trim()

        $edgePath = Resolve-EdgeExecutable

        if ([string]::IsNullOrWhiteSpace($edgePath)) {
            if ($chkArrange.Checked) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Microsoft Edge wurde nicht gefunden. Die Links werden im Standardbrowser geöffnet, ohne automatische Fensteranordnung.",
                    "Hinweis",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
            }

            Start-UrlInDefaultBrowser -Url $url1
            Start-UrlInDefaultBrowser -Url $url2

            & $setStatus "Edge nicht gefunden - Links im Standardbrowser geöffnet." $false
            & $saveCurrentSettings
            return
        }

        if ($chkArrange.Checked) {
            $beforeHandles1 = @((Get-EdgeMainWindows) | ForEach-Object { [Int64]$_.Handle })
            [void](Start-EdgeWindow -Url $url1 -EdgePath $edgePath)
            $leftHandle = Get-NewEdgeMainWindowHandle -BeforeHandles $beforeHandles1 -TimeoutMs 12000

            $beforeHandles2 = @((Get-EdgeMainWindows) | ForEach-Object { [Int64]$_.Handle })
            [void](Start-EdgeWindow -Url $url2 -EdgePath $edgePath)
            $rightHandle = Get-NewEdgeMainWindowHandle -BeforeHandles $beforeHandles2 -TimeoutMs 12000

            $tilingOk = Set-EdgeWindowsPrimarySplit -LeftHandle $leftHandle -RightHandle $rightHandle
            if (-not $tilingOk) {
                & $setStatus "Fenster geöffnet. Anordnung konnte nicht verifiziert werden." $true
                & $saveCurrentSettings
                return
            }
        }
        else {
            [void](Start-EdgeWindow -Url $url1 -EdgePath $edgePath)
            [void](Start-EdgeWindow -Url $url2 -EdgePath $edgePath)
        }

        & $setStatus "Fertig: Fenster wurden geöffnet." $false
        & $saveCurrentSettings
    }
    catch {
        & $setStatus "Fehler: $($_.Exception.Message)" $true
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$btnDoc.Add_Click({
    try {
        Open-Documentation
        & $setStatus "Dokumentation geöffnet." $false
    }
    catch {
        & $setStatus "Fehler: $($_.Exception.Message)" $true
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Fehler",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$btnClose.Add_Click({
    try {
        & $saveCurrentSettings
    }
    catch {
        # Beim Schließen keine harte Fehlermeldung erzwingen
    }

    $form.Close()
})

[void]$form.ShowDialog()





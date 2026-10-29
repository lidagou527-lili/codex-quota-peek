param([switch]$Check, [switch]$Demo, [string]$PreviewPath, [string]$DataDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing
if(!$DataDirectory){$DataDirectory=Join-Path $env:LOCALAPPDATA 'CodexQuotaPeek'}
$script:DataDirectory=[IO.Path]::GetFullPath($DataDirectory)
$script:ProjectRoot=$PSScriptRoot
$script:ConfigPath=Join-Path $script:DataDirectory 'settings.json'
function Read-Settings {
    try { return Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return Get-Content -LiteralPath (Join-Path $script:ProjectRoot 'settings.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json }
}
function Save-Settings($value) {
    $temporary=$script:ConfigPath+".$PID.tmp"
    $value | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $temporary -Encoding UTF8
    Move-Item -LiteralPath $temporary -Destination $script:ConfigPath -Force
}
$script:IsPreview=[bool]$PreviewPath
$script:IsDemo=[bool]($Demo -or $script:IsPreview)
$script:mutex=$null;$script:collector=$null
try {
    if(!$script:IsDemo -and !$Check){
        $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $script:mutex=New-Object Threading.Mutex($false,"Local\CodexQuotaPeek.$sid")
        try {$acquired=$script:mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$acquired=$true}
        if(!$acquired){[Windows.MessageBox]::Show('Codex Quota Peek is already running. Look for its tray icon.','Codex Quota Peek')|Out-Null;exit}
    }
    if(!$script:IsDemo){
        New-Item -ItemType Directory -Force -Path $script:DataDirectory | Out-Null
        if(!(Test-Path -LiteralPath $script:ConfigPath)){Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'settings.example.json') -Destination $script:ConfigPath}
        $nodePath=Join-Path $PSScriptRoot 'runtime\node.exe'
        if(!(Test-Path -LiteralPath $nodePath)){$nodeCommand=Get-Command node.exe -ErrorAction SilentlyContinue;if($nodeCommand){$nodePath=$nodeCommand.Source}}
        if(!(Test-Path -LiteralPath $nodePath)){throw 'Node.js 22+ is required. Download the portable release (includes Node), or install Node.js LTS from nodejs.org.'}
        $nodeVersion=& $nodePath --version
        if([int]($nodeVersion.TrimStart('v').Split('.')[0]) -lt 22){throw 'Node.js 22 or newer is required. Please use the portable release.'}
        $script:NodePath=$nodePath
        if($Check){& $nodePath (Join-Path $PSScriptRoot 'src\collector.cjs') '--once' "--data-dir=$script:DataDirectory";exit $LASTEXITCODE}
        function Start-Collector {
            $script:collectorStarted=Get-Date
            $script:collector=Start-Process -FilePath $script:NodePath -ArgumentList @(('"'+(Join-Path $script:ProjectRoot 'src\collector.cjs')+'"'),('"--data-dir='+$script:DataDirectory+'"'),"--owner=$PID") -WindowStyle Hidden -PassThru
        }
        Start-Collector
    }
    . (Join-Path $PSScriptRoot 'src\overlay.ps1')
} catch {
    if($Check -or $script:IsPreview){throw}
    [Windows.MessageBox]::Show($_.Exception.Message,'Codex Quota Peek')|Out-Null
} finally {
    if($script:mutex){if($acquired){$script:mutex.ReleaseMutex()};$script:mutex.Dispose()}
    # The collector watches this process and closes its own Codex child when this process exits.
}

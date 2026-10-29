$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
foreach($file in @('Start.ps1','src\overlay.ps1','scripts\build.ps1')){
    $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ($errors|Out-String)}
}
$image=Join-Path $env:TEMP ('quota-peek-preview-'+[guid]::NewGuid()+'.png')
& powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $root 'Start.ps1') -PreviewPath $image
if($LASTEXITCODE -ne 0 -or !(Test-Path $image)){throw 'WPF preview failed'}
if((Get-Item $image).Length -lt 1000){throw 'Preview output appears empty'}
'PASS: PowerShell syntax and WPF render smoke check'

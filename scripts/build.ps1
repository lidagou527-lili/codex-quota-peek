param([string]$NodeVersion)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$version=(Get-Content (Join-Path $root 'package.json') -Raw|ConvertFrom-Json).version
if(!$NodeVersion){$releases=Invoke-RestMethod 'https://nodejs.org/dist/index.json';$NodeVersion=($releases|Where-Object {$_.version -like 'v24.*' -and $_.lts -and $_.files -contains 'win-x64-zip'}|Select-Object -First 1).version}
if($NodeVersion -notmatch '^v24\.\d+\.\d+$'){throw 'A Node 24 LTS version is required'}
$cache=Join-Path $env:TEMP 'codex-quota-peek-build-cache';New-Item -ItemType Directory -Force $cache|Out-Null
$archiveName="node-$NodeVersion-win-x64.zip";$archive=Join-Path $cache $archiveName
$checksums=Invoke-WebRequest "https://nodejs.org/dist/$NodeVersion/SHASUMS256.txt" -UseBasicParsing
$match=[regex]::Match($checksums.Content,"(?m)^([a-f0-9]{64})\s+$([regex]::Escape($archiveName))\r?$")
if(!$match.Success){throw 'Official Node checksum not found'}
if(!(Test-Path $archive)){Invoke-WebRequest "https://nodejs.org/dist/$NodeVersion/$archiveName" -OutFile $archive -UseBasicParsing}
if((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $match.Groups[1].Value){throw 'Node archive checksum mismatch; remove the cached archive and retry'}
$expanded=Join-Path $cache "node-$NodeVersion-win-x64"
if(!(Test-Path (Join-Path $expanded 'node.exe'))){Expand-Archive -LiteralPath $archive -DestinationPath $cache -Force}
$dist=Join-Path $root 'dist';New-Item -ItemType Directory -Force $dist|Out-Null
$bundle=Join-Path $dist "codex-quota-peek-$version-win-x64"
if(Test-Path $bundle){throw "Bundle directory already exists; use a new version or move the existing directory: $bundle"}
New-Item -ItemType Directory -Force $bundle,(Join-Path $bundle 'src'),(Join-Path $bundle 'runtime'),(Join-Path $bundle 'docs')|Out-Null
$files=@('Start.ps1','Launch.cmd','settings.example.json','README.md','README.en.md','LICENSE','PRIVACY.md','CHANGELOG.md','THIRD-PARTY-NOTICES.md')
foreach($file in $files){Copy-Item -LiteralPath (Join-Path $root $file) -Destination (Join-Path $bundle $file)}
foreach($file in @('core.cjs','rpc.cjs','collector.cjs','overlay.ps1')){Copy-Item -LiteralPath (Join-Path $root "src\$file") -Destination (Join-Path $bundle "src\$file")}
Copy-Item -LiteralPath (Join-Path $root 'docs\preview.png') -Destination (Join-Path $bundle 'docs\preview.png')
Copy-Item -LiteralPath (Join-Path $expanded 'node.exe') -Destination (Join-Path $bundle 'runtime\node.exe')
Copy-Item -LiteralPath (Join-Path $expanded 'LICENSE') -Destination (Join-Path $bundle 'runtime\NODE-LICENSE.txt')
@{nodeVersion=$NodeVersion;nodeArchiveSha256=$match.Groups[1].Value;projectVersion=$version;architecture='win-x64'}|ConvertTo-Json|Set-Content (Join-Path $bundle 'BUILD-INFO.json') -Encoding UTF8
$zip=Join-Path $dist "codex-quota-peek-$version-win-x64.zip"
Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $zip -CompressionLevel Optimal
$hash=(Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($zip))"|Set-Content (Join-Path $dist 'SHA256SUMS.txt') -Encoding ASCII
Write-Output $zip

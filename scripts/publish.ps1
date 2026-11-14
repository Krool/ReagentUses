<#
.SYNOPSIS
  Uploads a built zip to CurseForge. Called by release.ps1 -Publish.

.NOTES
  UNTESTED against the live site for this project. The endpoints and field names follow the
  BigWigs packager (release.sh) and the Krool World Forever publish script:
    CurseForge  POST https://wow.curseforge.com/api/projects/<id>/upload-file
                header X-Api-Token, multipart "metadata" (JSON) + "file".
                Forever is game version type 88568; the version named for the current patch is
                used, else the newest of that type. Check the game version on every file.
  The id comes from the TOC (## X-Curse-Project-ID). The token comes from the user environment
  (CF_API_KEY) and is never printed. No relations are sent: this addon has no dependencies.
#>
param(
	[Parameter(Mandatory)] [string] $Zip,
	[Parameter(Mandatory)] [string] $Version,
	[string] $Notes = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http
$repo = Split-Path -Parent $PSScriptRoot
$toc = Join-Path $repo "ReagentUses\ReagentUses_Forever.toc"

function TocField([string] $name) {
	$hit = Select-String -Path $toc -Pattern "^## ${name}:\s*(.+)$"
	if ($hit) { return $hit.Matches[0].Groups[1].Value.Trim() }
	return $null
}
function EnvToken([string] $name) {
	$v = [Environment]::GetEnvironmentVariable($name, "Process")
	if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name, "User") }
	return $v
}

$interface = TocField "Interface"
$patch = "1.60.1" # Forever's game version for Interface 16001; update with the client

$cfId = TocField "X-Curse-Project-ID"
$cfToken = EnvToken "CF_API_KEY"
if (-not $cfId -or -not $cfToken) {
	Write-Host "CurseForge: skipped (needs ## X-Curse-Project-ID in the TOC and CF_API_KEY)."
	return
}

$client = New-Object System.Net.Http.HttpClient
$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Get), "https://wow.curseforge.com/api/game/wow/versions"
$req.Headers.Add("X-Api-Token", $cfToken)
$versions = $client.SendAsync($req).Result.Content.ReadAsStringAsync().Result | ConvertFrom-Json
$foreverAll = @($versions | Where-Object { $_.gameVersionTypeID -eq 88568 })
$forever = $foreverAll | Where-Object { $_.name -eq $patch } | Select-Object -First 1
if (-not $forever) { $forever = $foreverAll | Sort-Object id -Descending | Select-Object -First 1 }
if (-not $forever) { throw "CurseForge: no Forever game version (type 88568) found." }

$meta = @{ changelog = $Notes; changelogType = "markdown"; gameVersions = @($forever.id); releaseType = "release"; displayName = "ReagentUses-$Version" } | ConvertTo-Json -Compress -Depth 5
$file = New-Object System.Net.Http.ByteArrayContent (, [IO.File]::ReadAllBytes($Zip))
$file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/zip")
$form = New-Object System.Net.Http.MultipartFormDataContent
$form.Add((New-Object System.Net.Http.StringContent $meta), "metadata")
$form.Add($file, "file", [IO.Path]::GetFileName($Zip))
$req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Post), "https://wow.curseforge.com/api/projects/$cfId/upload-file"
$req.Headers.Add("X-Api-Token", $cfToken)
$req.Content = $form
$res = $client.SendAsync($req).Result
if (-not $res.IsSuccessStatusCode) { throw "CurseForge upload failed: $([int]$res.StatusCode) $($res.Content.ReadAsStringAsync().Result)" }
Write-Host "CurseForge: uploaded for game version $($forever.name) (interface $interface)."

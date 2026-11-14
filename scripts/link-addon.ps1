<#
.SYNOPSIS
  Junctions the ReagentUses folder from this repo into the Forever client's AddOns folder (no
  admin needed).

.EXAMPLE
  .\scripts\link-addon.ps1
  .\scripts\link-addon.ps1 -AddOnsPath "D:\Games\World of Warcraft\_forever_\Interface\AddOns"

.NOTES
  Forever installs to _forever_ (confirmed 2026-10-20). Restart the client (not just /reload) the
  first time so the TOC is picked up.
#>
param(
	[string] $AddOnsPath = "C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns"
)

$ErrorActionPreference = "Stop"
$Addon = "ReagentUses"
$repoRoot = Split-Path -Parent $PSScriptRoot

$source = "$repoRoot\$Addon"
if (-not (Test-Path "$source\${Addon}_Forever.toc")) { throw "Addon folder '$Addon' (with ${Addon}_Forever.toc) not found at the repo root." }

if (-not (Test-Path $AddOnsPath)) { New-Item -ItemType Directory -Path $AddOnsPath | Out-Null }
$link = Join-Path $AddOnsPath $Addon

if (Test-Path $link) {
	$item = Get-Item $link -Force
	if ($item.LinkType -eq "Junction" -and $item.Target -contains $source) {
		Write-Host "Already linked: $link -> $source"
		return
	}
	throw "'$link' already exists and is not a junction to $source. Remove it manually first."
}

New-Item -ItemType Junction -Path $link -Target $source | Out-Null
Write-Host "Linked: $link -> $source"
Write-Host "Restart the client (not just /reload) the first time so the TOC is picked up."

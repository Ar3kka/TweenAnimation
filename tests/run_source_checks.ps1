param([Parameter(Mandatory = $true)][string]$Godot)

$ErrorActionPreference = 'Stop'
$repository = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$checkDirectory = Join-Path $repository ('.tweenimation-check-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $checkDirectory | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $repository 'addons') -Destination $checkDirectory -Recurse
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'source_timeline.gd') -Destination (Join-Path $checkDirectory 'check.gd')
    $project = Join-Path $checkDirectory 'project.godot'
    @'
[application]
config/name="Tweenimation source regression checks"
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath $project -Encoding utf8
    $output = & $Godot --headless --path $checkDirectory --editor --import --quit 2>&1
    if ($LASTEXITCODE -ne 0 -or ($output | Select-String 'SCRIPT ERROR|^ERROR:')) { throw ($output -join "`n") }
    Add-Content -LiteralPath $project -Value "`n[editor_plugins]`nenabled=PackedStringArray(`"res://addons/tween_animation/plugin.cfg`")" -Encoding utf8
    $output = & $Godot --headless --path $checkDirectory --editor --quit-after 60 2>&1
    if ($LASTEXITCODE -ne 0 -or ($output | Select-String 'SCRIPT ERROR|^ERROR:')) { throw ($output -join "`n") }
    $output = & $Godot --headless --path $checkDirectory --script res://check.gd 2>&1
    $output | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($output | Select-String 'SCRIPT ERROR|^ERROR:') -or -not ($output | Select-String 'SOURCE_CHECK_FAILURES=0')) { throw 'Source regression checks failed.' }
}
finally {
    $resolvedCheck = (Resolve-Path -LiteralPath $checkDirectory).Path
    if ($resolvedCheck.StartsWith($repository + [IO.Path]::DirectorySeparatorChar) -and (Split-Path $resolvedCheck -Leaf).StartsWith('.tweenimation-check-')) {
        Remove-Item -LiteralPath $resolvedCheck -Recurse -Force
    }
}

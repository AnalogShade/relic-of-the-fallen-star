$scriptPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../scripts/stream_water.gd'))
$source = [System.IO.File]::ReadAllText($scriptPath)
$source = $source.Replace('const ENABLED := true', 'const ENABLED := false')
[System.IO.File]::WriteAllText($scriptPath, $source, [System.Text.UTF8Encoding]::new($false))
Write-Output 'Anciens rendus du ruisseau et du lac restaures. Relancer la scene dans Godot.'

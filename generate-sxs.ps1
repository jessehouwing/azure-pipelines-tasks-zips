$ErrorActionPreference="Stop"

$outputDir = mkdir "_gen" -force
$tasksToPatch = get-childitem "_download/*.zip"

foreach ($task in $tasksToPatch)
{
    if (Test-Path "_tmp")
    {
        Remove-Item "_tmp" -force -Recurse
    }

    $taskDir = "_tmp"

    if (Test-Path -path "_gen\$($task.Name -replace '^([^.]+).*-','$1-sxs*')" -PathType Leaf)
    {
        continue
    }

    # Expand-Archive -Path $task -DestinationPath _tmp
    & "C:\Program Files\7-Zip\7z.exe" x $task -o_tmp task*.json *.resjson -r -bd
    if ($LASTEXITCODE -ne 0)
    {
        Remove-item $task
        Write-Error "Failed to extract $task"
        continue
    }

    $taskManifestFiles = @("task.loc.json", "task.json")
    $manifest = @{}

    foreach ($taskManifestFile in $taskManifestFiles)
    {
        $manifestPath = "$taskDir/$taskManifestFile"
        if (Test-Path -Path $manifestPath -PathType Leaf)
        {
            $manifest = (Get-Content $manifestPath -raw) | ConvertFrom-Json -AsHashtable
            $manifest.name = "$($manifest.name)-sxs"
            if ($taskManifestFile -eq "task.json")
            {
                $manifest.friendlyName = "$($manifest.friendlyName) (Side-by-side)"
                if (Test-Path -Path "$taskDir\Strings" -PathType Container)
                {
                    $resourceFiles = Get-ChildItem "$taskDir\Strings\resources.resjson\resources.resjson" -recurse -ErrorAction "Continue"
                    foreach ($resourceFile in $resourceFiles)
                    {
                        $resources = (Get-Content $resourceFile -raw) | ConvertFrom-Json -AsHashtable
                        if ($resources["loc.friendlyName"])
                        {
                            $resources["loc.friendlyName"] = $manifest.friendlyName
                        }
                        $resources | ConvertTo-Json -depth 100 | Out-File $resourceFile -Encoding utf8NoBOM
                    }
                }
            }
            $manifest.id = Get-UUIDv5 $manifest.id $manifest.name
            $manifest | ConvertTo-Json -depth 100 | Out-File $manifestPath -Encoding utf8NoBOM
        }
    }

    $taskName = $manifest.name
    $taskid = $manifest.id
    $taskversion = "$($manifest.version.Major).$($manifest.version.Minor).$($manifest.version.Patch)"
    $taskZip = "$taskName.$taskid-$taskversion.zip"

    Copy-Item $task "_gen\$taskzip"
    Push-Location _tmp
    
    & "C:\Program Files\7-Zip\7z.exe" u "$outputDir\$taskzip" "*" -r -bd
    if ($LASTEXITCODE -ne 0)
    {
        Remove-Item "$outputDir\$taskzip"
        Write-Error "Failed to compress $task"
        continue
    }

    write-output "Created: $taskzip"
    Pop-Location
}

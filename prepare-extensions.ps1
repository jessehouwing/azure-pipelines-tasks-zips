[string[]] $existingReleases = & gh release list --repo jessehouwing/azure-pipelines-tasks-zips --limit 500 | Select-String "m\d+-tasks" | %{ $_.Matches.Value }
$allAssets = @()
foreach ($release in $existingReleases)
{
    $releaseDetails = & gh release view --repo jessehouwing/azure-pipelines-tasks-zips $release --json name,tagName,assets | ConvertFrom-Json
    $allAssets = $allAssets + $releaseDetails.assets
}

$org = "jessehouwing-brazil"
$pat = $env:AZURE_DEVOPS_PAT

$url = "https://dev.azure.com/$org"
$header = @{authorization = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(".:$pat")))"}

$tasks = Invoke-RestMethod -Uri "$url/_apis/distributedtask/tasks?allversions=true" -Method Get -ContentType "application/json" -Headers $header | ConvertFrom-Json -AsHashtable

$taskMetadata = $tasks.value

& npm install tfx-cli@0.21.3 -g --silent --no-progress

if (Test-Path "_vsix")
{
    Remove-Item "_vsix" -force -Recurse | Out-Null
}
mkdir _vsix | Out-Null

function get-extensions 
{
    return Get-ChildItem -Path .\extensions -Directory
}

function get-extensiontasks
{
    param(
        [string] $extensionId
    )

    return (get-content -raw "./extensions/$extensionId/tasks.json" | ConvertFrom-Json).tasks
}

function expand-taskprepostfixes 
{
    param(
        [string] $extensionId,
        [string] $taskname
    )

    $tasks = get-content -raw "./extensions/$extensionId/tasks.json" | ConvertFrom-Json

    $result = @()

    foreach ($prefix in $tasks.prefixes)
    {
        $result += "$prefix-$taskname"
    }

    foreach ($postfix in $tasks.postfixes)
    {
        $result += "$taskname-$postfix"
    }

    return $result
}

function get-versionsfortask
{
    param(
        [string] $taskName
    )

    # find all tasks with the given name
    $tasks =  $taskMetadata | Where-Object { $_.name -eq $taskName }

    # find all major versions for that task
    $majorversions = $tasks | foreach-object { $_.version.major } | Select-Object -Unique

    # find the latest version for each major version
    $result = $majorversions | ForEach-Object {
        $majorversion = $_
    
        $tasks | 
            where-object { $_.version.major -eq $majorversion} | 
            where-object { ([int]$_.version.minor) -ge 100} | 
            sort-object { [version]"$($_.version.major).$($_.version.minor).$($_.version.patch)" } | 
            select-object -last 1
    }
    
    return $result
}

function calculate-version
{
    param(
        [object[]] $versions
    )

    $maxminorversion = ($versions | measure-object -maximum { ([version]$_).Minor }).Maximum
    $maxbuildversion = ($versions | where-object { ([version]$_).Minor -eq $maxminorversion } | measure-object -maximum { ([version]$_).Build  }).Maximum
    $count = ($versions | where-object { 
        (([version]$_).Minor -eq $maxminorversion) -and
        (([version]$_).Build -eq $maxbuildversion)
    }).Count
    return "$maxminorversion.$maxbuildversion.$count"
}

function get-marketplace-version
{
    param(
        [string] $extensionId,
        [string] $publisher = "jessehouwing"
    )

    try {
        $json = & tfx extension show --publisher $publisher --extension-id $extensionId --json | ConvertFrom-Json
        if ($json.versions -and $json.versions.Count -gt 0) {
            return $json.versions[0].version
        }
    }
    catch {
        Write-Output "Could not retrieve marketplace version for $publisher.$extensionId (may not exist or network issue)"
    }
    
    return $null
}

function should-skip-extension-creation
{
    param(
        [string] $extensionId,
        [string] $extensionVersion,
        [string] $publisher = "jessehouwing"
    )

    $marketplaceVersion = get-marketplace-version -extensionId $extensionId -publisher $publisher
    
    if ($marketplaceVersion -and $marketplaceVersion -eq $extensionVersion) {
        Write-Output "Extension $publisher.$extensionId version $extensionVersion already exists in marketplace, skipping creation"
        return $true
    }
    
    if ($marketplaceVersion) {
        Write-Output "Extension $publisher.$extensionId marketplace version: $marketplaceVersion, building version: $extensionVersion"
    } else {
        Write-Output "Extension $publisher.$extensionId not found in marketplace or network issue, proceeding with creation"
    }
    
    return $false
}

function calculate-extension-version-metadata-only
{
    param(
        [string] $extensionId
    )

    $tasks = get-extensiontasks -extensionId $extensionId
    if ($tasks.Count -eq 0)
    {
        return $null
    }

    $taskversions = @()
    foreach ($task in $tasks)
    {
        $versions = get-versionsfortask -taskName $task

        foreach ($taskName in expand-taskprepostfixes -extensionId $extensionId -taskName $task)
        {
            foreach ($version in $versions)
            {
                $taskVersion = "$($version.version.major).$($version.version.minor).$($version.version.patch)"
                $taskversions += $taskVersion
            }
        }
    }

    if ($taskversions.Count -eq 0) {
        return $null
    }

    return calculate-version -versions $taskversions
}

$extensions = get-extensions
foreach ($extension in $extensions)
{
    $tasks = get-extensiontasks -extensionId $extension.Name
    if ($tasks.Count -eq 0)
    {
        Write-Output "Extension $($extension.Name) has no tasks, skipping"
        continue
    }

    # Calculate extension version early using only metadata
    $extensionVersion = calculate-extension-version-metadata-only -extensionId $extension.Name
    
    if (-not $extensionVersion) {
        Write-Output "Could not calculate version for extension $($extension.Name), skipping"
        continue
    }

    # Check marketplace versions early to avoid unnecessary work
    $skipMainExtension = should-skip-extension-creation -extensionId "$($extension.Name)" -extensionVersion $extensionVersion
    $skipDebugExtension = should-skip-extension-creation -extensionId "$($extension.Name)-debug" -extensionVersion $extensionVersion
    
    if ($skipMainExtension -and $skipDebugExtension) {
        Write-Output "Both main and debug versions of extension $($extension.Name) v$extensionVersion already exist in marketplace, skipping entirely"
        continue
    }

    Write-Output "Processing extension $($extension.Name) v$extensionVersion"
    
    # Only now proceed with downloading, extracting, and building
    Remove-Item -Recurse "extensions/$($extension.Name)/_tasks" -Force -ErrorAction SilentlyContinue

    $extensionManifest = ConvertFrom-Json -InputObject (get-content -raw "./extensions/vss-extension.json") 
    $extensionManifest.contributions = @()
    
    foreach ($task in $tasks)
    {
        $versions = get-versionsfortask -taskName $task

        foreach ($taskName in expand-taskprepostfixes -extensionId $($extension.Name) -taskName $task)
        {
            foreach ($version in $versions)
            {
                $taskVersion = "$($version.version.major).$($version.version.minor).$($version.version.patch)"
                $taskzip = $allAssets | Where-Object { $_.name -ilike "$taskName.*-$taskVersion.zip" } | Select-Object -First 1
                if (-not $taskzip)
                {
                    $taskzip = dir "./_gen/$taskName.*-$taskVersion.zip" | Select-Object -First 1
                    $filePath = "./_gen/$($taskzip.Name)"
                }
                else {
                    $filePath = "./_gen/$($taskzip.name)"
                    if (-not (Test-Path -PathType leaf -Path $filePath))
                    {
                        & gh release download --repo jessehouwing/azure-pipelines-tasks-zips "m$($version.version.minor)-tasks" --pattern "$taskName.*-$taskVersion.zip" --dir ./_gen
                    }
                }
                
                Expand-Archive -Path $filePath -DestinationPath "extensions/$($extension.Name)/_tasks/$taskName/v$taskVersion"
                write-output "Added: $taskName/v$taskVersion"
            }

            # Hack to fixup contributionIds that can't be changed.
            $contributionId = $taskName
            $contributionId = $contributionId -replace "^(Pre|Post)-(CmdLine|PowerShell)$","`$0V2"
            $contributionId = $contributionId -replace "^(Pre|Post)-(Bash)$","`$0V3"

            $extensionManifest.contributions += [ordered] @{
                "id" = "$contributionId"
                "type" = "ms.vss-distributed-task.task"
                "targets" = @("ms.vss-distributed-task.tasks")
                "properties" = @{
                    "name" = "_tasks/$taskName"
                }
            }
        }
    }

    # fix-up paths and files
    if (test-path -PathType Leaf -path "extensions/$($extension.Name)/fix.ps1")
    {
        Push-Location "extensions/$($extension.Name)"
        & .\fix.ps1
        Pop-Location
    }

    $extensionManifest.version = $extensionVersion

    $extensionManifest | ConvertTo-Json -depth 100 | Out-File "extensions/$($extension.Name)/vss-extension.tasks.json" -Encoding utf8NoBOM
    Copy-Item .\extensions\vss-extension.debug.json "extensions/$($extension.Name)"
    Copy-Item .\LICENSE "extensions/$($extension.Name)"
    Copy-Item .\PRIVACY.md "extensions/$($extension.Name)"

    Push-Location "extensions/$($extension.Name)"
    
    if (-not $skipMainExtension) {
        Write-Output "Creating main extension: jessehouwing.$($extension.Name)-$extensionVersion.vsix"
        & tfx extension create --extension-id "$($extension.Name)" --manifests "vss-extension.json" "vss-extension.public.json" "vss-extension.tasks.json" --output-path "..\..\_vsix\_jessehouwing.$($extension.Name)-$extensionVersion.vsix"
    }
    
    if (-not $skipDebugExtension) {
        Write-Output "Creating debug extension: jessehouwing.$($extension.Name)-debug-$extensionVersion.vsix"
        & tfx extension create --extension-id "$($extension.Name)-debug" --manifests "vss-extension.json" "vss-extension.debug.json" "vss-extension.tasks.json" --output-path "..\..\_vsix\_jessehouwing.$($extension.Name)-debug-$extensionVersion.vsix"
    }
    
    Pop-Location
}

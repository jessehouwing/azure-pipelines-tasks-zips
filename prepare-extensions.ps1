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

& npm install tfx-cli@^0.18 -g --silent --no-progress

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

$extensions = get-extensions
foreach ($extension in $extensions)
{
    Remove-Item -Recurse "extensions/$($extension.Name)/_tasks" -Force -ErrorAction SilentlyContinue
    $tasks = get-extensiontasks -extensionId $extension.Name
    if ($tasks.Count -eq 0)
    {
        continue
    }

    $extensionManifest = ConvertFrom-Json -InputObject (get-content -raw "./extensions/vss-extension.json") 
    $extensionManifest.contributions = @()
    
    $taskversions = @()
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
                $taskversions += $taskVersion
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

    $extensionVersion = calculate-version -versions $taskversions

    $extensionManifest.version = $extensionVersion

    $extensionManifest | ConvertTo-Json -depth 100 | Out-File "extensions/$($extension.Name)/vss-extension.tasks.json" -Encoding utf8NoBOM
    Copy-Item .\extensions\vss-extension.debug.json "extensions/$($extension.Name)"
    Copy-Item .\LICENSE "extensions/$($extension.Name)"
    Copy-Item .\PRIVACY.md "extensions/$($extension.Name)"

    Push-Location "extensions/$($extension.Name)"
    & tfx extension create --extension-id "$($extension.Name)" --manifests "vss-extension.json" "vss-extension.public.json" "vss-extension.tasks.json" --output-path "..\..\_vsix\_jessehouwing.$($extension.Name)-$extensionVersion.vsix"
    & tfx extension create --extension-id "$($extension.Name)-debug" --manifests "vss-extension.json" "vss-extension.debug.json" "vss-extension.tasks.json" --output-path "..\..\_vsix\_jessehouwing.$($extension.Name)-debug-$extensionVersion.vsix"
    Pop-Location
}

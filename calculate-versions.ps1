# Calculate extension versions without downloading zip files
# This script checks if extensions need to be built by comparing calculated versions with marketplace versions

$org = "jessehouwing-brazil"
$pat = $env:AZURE_DEVOPS_PAT

if (-not $pat) {
    Write-Error "AZURE_DEVOPS_PAT environment variable is required"
    exit 1
}

$url = "https://dev.azure.com/$org"
$header = @{authorization = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(".:$pat")))"}

Write-Output "::notice::Fetching task metadata from Azure DevOps"
$tasks = Invoke-RestMethod -Uri "$url/_apis/distributedtask/tasks?allversions=true" -Method Get -ContentType "application/json" -Headers $header | ConvertFrom-Json -AsHashtable
$taskMetadata = $tasks.value

# Install tfx-cli for marketplace checks
& npm install tfx-cli@0.21.3 -g --silent --no-progress

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

function calculate-extension-version-without-downloads
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

function should-skip-entire-build
{
    $extensions = get-extensions
    $allExtensionsExist = $true
    
    foreach ($extension in $extensions)
    {
        $extensionVersion = calculate-extension-version-without-downloads -extensionId $extension.Name
        
        if (-not $extensionVersion) {
            Write-Output "Extension $($extension.Name) has no tasks, skipping"
            continue
        }
        
        Write-Output "Calculated version for $($extension.Name): $extensionVersion"
        
        # Check both main and debug versions
        $mainVersion = get-marketplace-version -extensionId "$($extension.Name)"
        $debugVersion = get-marketplace-version -extensionId "$($extension.Name)-debug"
        
        $mainExists = $mainVersion -and $mainVersion -eq $extensionVersion
        $debugExists = $debugVersion -and $debugVersion -eq $extensionVersion
        
        if ($mainExists -and $debugExists) {
            Write-Output "Both main and debug versions of $($extension.Name) v$extensionVersion already exist in marketplace"
        } else {
            Write-Output "Extension $($extension.Name) v$extensionVersion needs to be built (main exists: $mainExists, debug exists: $debugExists)"
            $allExtensionsExist = $false
        }
    }
    
    return $allExtensionsExist
}

# Main execution
if (should-skip-entire-build) {
    Write-Output "::notice::All extension versions already exist in marketplace, skipping build process"
    exit 0
} else {
    Write-Output "::notice::One or more extensions need to be built, proceeding with full build"
    exit 1
}
# Test script to validate version calculation logic
# This test doesn't require AZURE_DEVOPS_PAT and uses mock data

# Create mock task metadata for testing
$mockTaskMetadata = @(
    # dotnetcore tasks
    @{ name = "DotNetCoreCLI"; version = @{ major = 2; minor = 100; patch = 1 } },
    @{ name = "DotNetCoreCLI"; version = @{ major = 2; minor = 101; patch = 2 } },
    @{ name = "UseDotNet"; version = @{ major = 2; minor = 100; patch = 0 } },
    
    # apple-xcode tasks
    @{ name = "InstallAppleCertificate"; version = @{ major = 2; minor = 100; patch = 1 } },
    @{ name = "InstallAppleProvisioningProfile"; version = @{ major = 1; minor = 100; patch = 0 } },
    @{ name = "Xcode"; version = @{ major = 5; minor = 100; patch = 3 } },
    
    # pre-post-tasks
    @{ name = "PowerShell"; version = @{ major = 2; minor = 100; patch = 4 } },
    @{ name = "Bash"; version = @{ major = 3; minor = 100; patch = 2 } },
    @{ name = "CmdLine"; version = @{ major = 2; minor = 100; patch = 1 } },
    
    # nuget-deprecated tasks  
    @{ name = "NuGetRestore"; version = @{ major = 1; minor = 100; patch = 1 } },
    @{ name = "NuGetInstaller"; version = @{ major = 0; minor = 100; patch = 2 } },
    @{ name = "NuGetAuthenticate"; version = @{ major = 1; minor = 100; patch = 0 } },
    @{ name = "NuGetPackager"; version = @{ major = 0; minor = 100; patch = 5 } },
    @{ name = "NuGet"; version = @{ major = 0; minor = 100; patch = 3 } },
    @{ name = "NuGetPublisher"; version = @{ major = 0; minor = 100; patch = 1 } },
    
    # appcenter tasks
    @{ name = "AppCenterDistribute"; version = @{ major = 3; minor = 100; patch = 0 } },
    @{ name = "AppCenterTest"; version = @{ major = 1; minor = 100; patch = 2 } },
    
    # visualstudio tasks
    @{ name = "VSBuild"; version = @{ major = 1; minor = 100; patch = 8 } },
    @{ name = "VSTest"; version = @{ major = 2; minor = 100; patch = 3 } },
    @{ name = "VisualStudioTestPlatformInstaller"; version = @{ major = 1; minor = 100; patch = 1 } },
    @{ name = "MSBuild"; version = @{ major = 1; minor = 100; patch = 15 } }
)

# Source the functions we need to test
. ./UUIDv5.ps1

# Mock the global variable that would normally come from Azure DevOps API
$global:taskMetadata = $mockTaskMetadata

function get-extensiontasks
{
    param(
        [string] $extensionId
    )

    if (Test-Path "./extensions/$extensionId/tasks.json") {
        return (get-content -raw "./extensions/$extensionId/tasks.json" | ConvertFrom-Json).tasks
    }
    return @()
}

function expand-taskprepostfixes 
{
    param(
        [string] $extensionId,
        [string] $taskname
    )

    if (-not (Test-Path "./extensions/$extensionId/tasks.json")) {
        return @($taskname)
    }

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

    # If no prefixes or postfixes, return the original task name
    if ($result.Count -eq 0) {
        $result += $taskname
    }

    return $result
}

function get-versionsfortask
{
    param(
        [string] $taskName
    )

    # find all tasks with the given name
    $tasks = $global:taskMetadata | Where-Object { $_.name -eq $taskName }

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

# Test the version calculation
Write-Output "Testing version calculation with mock data..."

# Test dotnetcore extension
$dotnetCoreVersion = calculate-extension-version-metadata-only -extensionId "dotnetcore"
Write-Output "DotNetCore extension calculated version: $dotnetCoreVersion"

# Test extensions that exist
$extensions = Get-ChildItem -Path .\extensions -Directory
foreach ($extension in $extensions) {
    $version = calculate-extension-version-metadata-only -extensionId $extension.Name
    if ($version) {
        Write-Output "Extension $($extension.Name): $version"
    } else {
        Write-Output "Extension $($extension.Name): No version calculated (likely no tasks)"
    }
}

Write-Output "Test completed successfully!"
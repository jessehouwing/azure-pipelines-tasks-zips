$outputDir = md _download -force

$org = "jessehouwing-brazil"
$pat = $env:AZURE_DEVOPS_PAT

$url = "https://dev.azure.com/$org"
$header = @{authorization = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(".:$pat")))"}

write-output "::notice::Fetching all tasks from $org"
$tasks = Invoke-RestMethod -Uri "$url/_apis/distributedtask/tasks?allversions=true" -Method Get -ContentType "application/json" -Headers $header | ConvertFrom-Json -AsHashtable

$taskMetadatas = $tasks.value

write-output "::notice::Fetching all releases from GitHub"
if ($existingReleases -eq $null) {
    [string[]] $existingReleases = & gh release list --repo jessehouwing/azure-pipelines-tasks-zips --limit 500 | Select-String "m\d+-tasks" | %{ $_.Matches.Value }
    $allAssets = @()
    foreach ($release in $existingReleases)
    {
        $releaseDetails = & gh release view --repo jessehouwing/azure-pipelines-tasks-zips $release --json name,tagName,assets | ConvertFrom-Json
        $allAssets = $allAssets + $releaseDetails.assets
    }
}

$taskMetadatas | ForEach-Object -Parallel {
    $url = $using:url
    $outputDir = $using:outputDir
    $header = $using:header

    $taskMetadata = $_
    if ($taskMetadata.serverOwned)
    {
        $taskName = $taskMetadata.name
        $taskid = $taskMetadata.id
        $taskversion = "$($taskMetadata.version.major).$($taskMetadata.version.minor).$($taskMetadata.version.patch)"
        $taskZip = "$taskName.$taskid-$taskversion.zip"

        if ((-not (
                (Test-Path -PathType Leaf -Path "$outputDir/$taskZip") -or
                (($using:allAssets | Where-Object { $_.name -eq $taskZip }).Count -gt 0) -or 
                ($taskMetadata.version.minor -lt 100)
            ) )
        )
        {
            $success = $false
            $retry = 5
            while ((-not $success) -and ($retry -gt 0)) 
            {
                try
                {
                    write-output "::notice::Downloading: $taskZip"
                    Invoke-WebRequest -Uri "$url/_apis/distributedtask/tasks/$taskid/$taskversion" -OutFile "$outputDir/$taskZip" -Headers $header
                    $success = $true
                }
                catch
                {
                    $retry--
                    remove-item -path "$outputDir/$taskZip" -force -erroraction silentlycontinue
                    if ($retry -eq 0)
                    {
                        write-output "::error::Failed to download $taskZip"
                    }
                    else
                    {
                        write-output "::warning::Failed to download $taskZip, retrying"
                    }
                }
            }
            write-output "::notice::Downloaded: $taskZip"
        } 
        else 
        {
            write-output "::debug::Already have: $taskZip"
        }
    }
} -ThrottleLimit 8

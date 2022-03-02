$outputDir = md _download -force

$org = "jessehouwing"
$pat = $env:AZURE_DEVOPS_PAT

$url = "https://dev.azure.com/$org"
$header = @{authorization = "Basic $([Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(".:$pat")))"}

$tasks = Invoke-RestMethod -Uri "$url/_apis/distributedtask/tasks" -Method Get -ContentType "application/json" -Headers $header | ConvertFrom-Json -AsHashtable

$taskMetadatas = $tasks.value

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

        if (-not (Test-Path -PathType Leaf -Path "$outputDir/$taskZip"))
        {
            Invoke-WebRequest -Uri "$url/_apis/distributedtask/tasks/$taskid/$taskversion" -OutFile "$outputDir/$taskZip" -Headers $header
            write-output "Downloaded: $taskZip"
        }
    }
} -ThrottleLimit 8

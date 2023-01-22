[string[]] $existingReleases = & gh release list --repo jessehouwing/azure-pipelines-tasks-zips --limit 500 | Select-String "m\d+-tasks" | %{ $_.Matches.Value }
$knownAssets = @{}

foreach ($release in $existingReleases)
{
    $releaseDetails = & gh release view --repo jessehouwing/azure-pipelines-tasks-zips $release --json name,tagName,assets | ConvertFrom-Json

    $knownAssets["$release"] = $releaseDetails.assets
}

foreach ($taskzip in (dir _sxs/*.zip) + (dir .\_download\*.zip))
{
    $taskzip.Name -match "-(?<version>\d+\.\d+\.\d+)\.zip" | Out-Null
    $version = [version]$Matches.version

    if ($version.Minor -lt 100)
    {
        continue
    }

    if ($knownAssets."m$($version.Minor)-tasks")
    {
        if ($knownAssets."m$($version.Minor)-tasks" | Where-Object { $_.name -eq $taskzip.Name })
        {
            continue
        }
        & gh release upload --repo jessehouwing/azure-pipelines-tasks-zips "m$($version.Minor)-tasks" $taskzip.FullName
    }
    else {
        & gh release create --repo jessehouwing/azure-pipelines-tasks-zips --title "m$($version.Minor) - Tasks" --notes-file .\releasenote.template.md "m$($version.Minor)-tasks" $taskzip.FullName
        $knownAssets."m$($version.Minor)-tasks" = @()
    }
}
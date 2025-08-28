if (test-path -PathType Leaf ./_vsix/*.vsix) {
    & npm install tfx-cli@^0.22 --location=global --no-fund
    $anyFailures = $false
    foreach ($vsix in dir ./_vsix/*.vsix) {
        Write-Output "Publishing: $($vsix.FullName)"
        Write-Output "::group::Checking extension version for $($vsix.Name)"
        $json = (& tfx extension show --token $env:AZURE_MARKETPLACE_PAT --vsix $vsix.FullName --json) | ConvertFrom-Json
        Write-Output "::endgroup::"
               
        if (-not ($json.versions -and $json.versions.count -gt 0 -and $vsix.FullName.EndsWith("$($json.versions[0].version).vsix"))) {
            Write-Output "::group::Publishing extension $($vsix.Name)"
            & tfx extension publish --vsix $vsix.FullName --token $env:AZURE_MARKETPLACE_PAT --no-wait-validation
            if ($LASTEXITCODE -ne 0) {
                Write-Output "::error::Failed to publish extension $($vsix.Name)"
                $anyFailures = $true
            }
            else {
                Write-Output "::notice::Successfully published extension $($vsix.Name)"
            }
            Write-Output "::endgroup::"
        }
        else {
            Write-Output "::notice::Extension $($vsix.Name) is already up to date, skipping publish"
        }
    }
            
    foreach ($vsix in dir ./_vsix/*.vsix) {
        $sleep = 0
        Write-Output "::group::Validating extension $($vsix.Name)"
        do {
            $status = & tfx extension isvalid --vsix $vsix.FullName --service-url https://marketplace.visualstudio.com/ --token $env:AZURE_MARKETPLACE_PAT --json | ConvertFrom-Json
            Start-Sleep -Seconds $sleep
            $sleep = $sleep + 15
        } while ($status.status -eq "pending")

        if ($status.status -ne "success") {
            Write-Output "::error::Extension validation failed for extension $($vsix.Name)"
            write-output $status.message.message
            $anyFailures = $true
        }
        Write-Output "::endgroup::"
    }

    if ($anyFailures) {
        Write-Output "::error::One or more extensions failed to publish"
        exit 1
    }
}
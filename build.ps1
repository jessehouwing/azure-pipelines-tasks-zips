. .\download.ps1
. .\UUIDv5.ps1
. .\generate-sxs.ps1
. .\generate-deprecated.ps1
. .\generate-pre-post.ps1
. .\upload-releases.ps1

# Check if we can skip extension preparation
Write-Output "::group::Checking marketplace versions"
. .\calculate-versions.ps1
$shouldSkipExtensions = $LASTEXITCODE -eq 0
Write-Output "::endgroup::"

if ($shouldSkipExtensions) {
    Write-Output "::notice::All extensions are up to date, skipping extension preparation"
    exit 0
}

Write-Output "::notice::Proceeding with extension preparation"
. .\prepare-extensions.ps1
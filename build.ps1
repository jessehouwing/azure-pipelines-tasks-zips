# Check if we can skip the entire build process
Write-Output "::group::Checking marketplace versions"
. .\calculate-versions.ps1
$shouldSkipBuild = $LASTEXITCODE -eq 0
Write-Output "::endgroup::"

if ($shouldSkipBuild) {
    Write-Output "::notice::All extensions are up to date, skipping build"
    exit 0
}

Write-Output "::notice::Proceeding with full build process"
. .\download.ps1
. .\UUIDv5.ps1
. .\generate-sxs.ps1
. .\generate-deprecated.ps1
. .\generate-pre-post.ps1
. .\upload-releases.ps1
. .\prepare-extensions.ps1
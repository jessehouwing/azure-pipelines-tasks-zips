$extensions = @(
    @{
        "Id" = "VisualStudio"
        "Tasks" = @("vsbuild",  "vstest", "visualstudiotestplatforminstaller",  "msbuild")
    },
    @{
        "Id" = "DotNetCore"
        "Tasks" = @("dotnetcorecli", "dotnetcoreinstaller")
    }
    
    # Can't build a NuGet extension as it exceeds the maximum extension size for she marketplace.
    #@{
    #    "Id" = "NuGet"
    #    "Tasks" = @("NuGetAuthenticate", "NuGetCommand", "NuGetInstaller", "NuGetPackager", "NuGetPublisher", "NuGet", "NuGetToolInstaller")
    #}
)

& npm install tfx-cli@latest -g

if (Test-Path "_vsix")
{
    rd "_vsix" -force -Recurse
}
md _vsix

foreach ($extension in $extensions)
{
    write-output "Building extension: $extension"
    if (Test-Path "_tmp")
    {
        rd "_tmp" -force -Recurse
    }
    md _tmp
    $extensionManifest = gc "vss-extension.json" | ConvertFrom-Json
    $extensionManifest.contributions = @()

    foreach ($task in $extension.Tasks)
    {
        foreach ($zip in dir _sxs/$task-sxs.*.zip)
        {
            $zip.NameString -match "(?<version>\d+\.\d+\.\d+)"
            $taskVersion = $Matches.version

            Expand-Archive -Path $zip -DestinationPath _tmp/_tasks/$task-sxs/v$taskVersion
            write-output "Added: $task-sxs/v$taskVersion"
        }

        $extensionManifest.contributions += [ordered] @{
            "id" = "$task-sxs"
            "type" = "ms.vss-distributed-task.task"
            "targets" = @("ms.vss-distributed-task.tasks")
            "properties" = @{
                "name" = "_tasks/$task-sxs"
            }
        }
    }

    # Generate vss-extension.json

    [console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding
    $extensionManifest.version = "1.$env:VERSION.3"
    $extensionManifest | ConvertTo-Json -depth 100 | Out-File "_tmp/vss-extension.json" -Encoding utf8NoBOM
    copy .\vss-extension.$($extension.Id).json _tmp
    copy .\icon-*.png _tmp
    copy .\*.md _tmp
    copy .\LICENSE _tmp
    pushd .\_tmp
    
    ren overview.$($extension.Id).md overview.md
    del overview.*.md
    & tfx extension create --manifests vss-extension.$($extension.Id).json vss-extension.json
    
    popd
    copy ./_tmp/*.vsix ./_vsix
}

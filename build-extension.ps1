$extensions = @(
    @{
        "Id" = "VisualStudio"
        "Tasks" = @("vsbuild",  "vstest", "visualstudiotestplatforminstaller",  "msbuild")
    },
    @{
        "Id" = "DotNetCore"
        "Tasks" = @("dotnetcorecli", "dotnetcoreinstaller", "UseDotNet")
    },
    @{
        "Id" = "Apple-Xcode"
        "Tasks" = @("InstallAppleCertificate", "InstallAppleProvisioningProfile", "Xcode")
    }
    #@{
    #    "Id" = "Azure"
    #    "Tasks" = @(
    #        "AzureFileCopy", 
    #        "AzurePowerShell", 
    #        "AzureResourceGroupDeployment", 
    #        "AzureResourceManagerTemplateDeployment"
    #    )
    #}

    # Can't build a NuGet extension as it exceeds the maximum extension size for she marketplace.
    #@{
    #    "Id" = "NuGet"
    #    "Tasks" = @("NuGetAuthenticate", "NuGetCommand", "NuGetInstaller", "NuGetPackager", "NuGetPublisher", "NuGet", "NuGetToolInstaller")
    #}
)

& npm install tfx-cli@latest -g --silent --no-progress

if (Test-Path "_vsix")
{
    rd "_vsix" -force -Recurse | Out-Null
}
md _vsix | Out-Null

foreach ($extension in $extensions)
{
    write-output "Building extension: $($extension.Id)"
    if (Test-Path "_tmp")
    {
        rd "_tmp" -force -Recurse | Out-Null
    }
    md _tmp | Out-Null

    $extensionManifest = gc "./extensions/vss-extension.json" | ConvertFrom-Json
    $extensionManifest.contributions = @()

    foreach ($task in $extension.Tasks)
    {
        foreach ($zip in dir _sxs/$task-sxs.*.zip)
        {
            $zip.NameString -match "(?<version>\d+\.\d+\.\d+)" | Out-Null
            $taskVersion = $Matches.version

            Expand-Archive -Path $zip -DestinationPath _tmp/_tasks/$task-sxs/v$taskVersion
            write-output "Added: $task-sxs/v$taskVersion"
        }

        Get-ChildItem -Recurse -Filter "* *" -Path "_tmp/_tasks/$task-sxs/" | Rename-Item -NewName { $_.Name -replace " ", "_" }

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
    $extensionManifest.version = "1.$env:VERSION.6"

    $extensionManifest | ConvertTo-Json -depth 100 | Out-File "_tmp/vss-extension.tasks.json" -Encoding utf8NoBOM
    
    copy .\extensions\$($extension.Id)\vss-extension.onprem.json _tmp
    copy .\extensions\$($extension.Id)\vss-extension.json _tmp
    copy .\extensions\$($extension.Id)\icon-*.png _tmp
    copy .\extensions\$($extension.Id)\*.md _tmp
    copy .\extensions\vss-extension.cloud.json _tmp
    copy .\*.md _tmp
    copy .\LICENSE _tmp
    pushd .\_tmp

    & tfx extension create --extension-id "$($extension.Id)" --manifests "vss-extension.json" "vss-extension.onprem.json" "vss-extension.tasks.json" --output-path "_jessehouwing.$($extension.Id).vsix"
    & tfx extension create --extension-id "$($extension.Id)-debug" --manifests "vss-extension.json" "vss-extension.cloud.json" "vss-extension.tasks.json" --output-path "_jessehouwing.$($extension.Id)-debug.vsix"

    popd
    copy ./_tmp/*.vsix ./_vsix
}

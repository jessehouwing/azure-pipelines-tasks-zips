# TaskName.guid-1.200.71.zip

This zip contains a verbatim copy of the task. They are downloaded directly from my Azure DevOps organisation and are published unchanged.

# TaskName-sxs.guid.1.200.71.zip

This zip contains a patched copy of the task. These tasks can be installed side-by-side with the built-in tasks. All tasks have a new unique id and the task's name has been post-pended with `-sxs`.

# Installation

To install these tasks into your Team Foundation Server / Azure DevOps Server use `tfx`:

```
npm install -g tfx-cli
tfx build tasks upload --task-zip-path Task.guid-version.zip --service-url https://yourtfs.com/tfs/DefaultCollection
```

Or [this PowerShell script](https://github.com/jessehouwing/azure-pipelines-tasks-zips/blob/main/scripts/install-task.ps1):

```
. ./script/install-task.ps1 -CollectionUrl https://yourtfs.com/tfs/DefaultCollection -TaskZip Task.guid-version.zip
```
                            
# Extension

A few tasks seem to be getting the most demand. I've added a pre-built extension for those and also published these to the marketplace:

 * 🛍️ [Visual Studio 2022 for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.visualstudio)
 * 🛍️ [DotNetCore 6 for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.dotnetcore)

These extensions install the side-by-side version into your Azure DevOps Server.
                                              

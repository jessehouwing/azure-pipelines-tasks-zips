# Azure Pipelines Tasks Zips & Extensions 🗜️📁

This repository contains a pre-built version of the built-in tasks of Azure DevOps. In case you need to install an updated version into Team Foundation Server or Azure DevOps Server, you can use these zips.

You can download the tasks from the Releases in this repository. [You'll find two kinds of task zips in the releases](https://github.com/jessehouwing/azure-pipelines-tasks-zips/releases/latest).

The releases are named after the [current release milestone of the azure-pipelines-tasks repo](https://github.com/microsoft/azure-pipelines-tasks/branches/all?query=releases%2Fm).

## TaskName.guid-1.200.71.zip

This zip contains a verbatim copy of the task. They are downloaded directly from my Azure DevOps organisation and are published unchanged.

## TaskName-sxs.guid.1.200.71.zip

This zip contains a patched copy of the task. These tasks can be installed side-by-side with the built-in tasks. All tasks have a new unique id and the task's name has been post-pended with `-sxs`.

# Installation

[Download the task from the latest release from this repository](https://github.com/jessehouwing/azure-pipelines-tasks-zips/releases). To install these tasks into your Team Foundation Server / Azure DevOps Server use `tfx`:

```
npm install -g tfx-cli
tfx build tasks upload --task-zip-path Task.guid-version.zip --service-url https://yourtfs.com/tfs/DefaultCollection
```

Or [this PowerShell script](./scripts/install-task.ps1):

```
. ./script/install-task.ps1 -CollectionUrl https://yourtfs.com/tfs/DefaultCollection -TaskZip Task.guid-version.zip
```
# Extension

A few tasks seem to be getting the most demand. I've added a pre-built extension for those and also published these to the marketplace:
 
 * 🛍️ [AppCenter for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.appcenter)
 * 🛍️ [Apple Xcode for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.Apple-Xcode)
 * 🛍️ [DotNetCore 6 and 7 for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.dotnetcore)
 * 🛍️ [Nuget (Deprecated)](https://marketplace.visualstudio.com/items?itemName=jessehouwing.nuget-deprecated)
 * 🛍️ [Pre and post script tasks](https://marketplace.visualstudio.com/items?itemName=jessehouwing.pre-post-tasks)
 * 🛍️ [Visual Studio 2022 for Azure DevOps Server](https://marketplace.visualstudio.com/items?itemName=jessehouwing.visualstudio)

These extensions install the side-by-side version into your Azure DevOps Server.

# Required agent version

You will need to [install a recent agent (2.195.0 or newer) from the azure-pipelines-agent repository](https://github.com/microsoft/azure-pipelines-agent/releases) for it to auto-detect Visual Studio 2022, or alternatively add the capabilities to the agent manually.

You may need to force Azure DevOps Server to not downgrade back to its preferred agent version. You can do so by setting the following environment variable at the system level on your server before launching the agent:

```
AZP_AGENT_DOWNGRADE_DISABLED=true
```

# Maximum extension size

For on-premise installations there is a maximum extension size configured for the internal marketplace. Some of the extensions might not meet the configured maximum. If this is the case you'll receive an error message similar to the following:

```
Upload Error

The extension package size '38060652 bytes' exceeds the maximum package size '26214400 bytes'
```

To work around this issue, you can [use the installation method that pushes the task-zips directly](#installation) or increase the configured maximum by running the following SQL statement against your Azure DevOps Server Configuration database using a size that is bigger than the one reported in the error message:

```
DECLARE @keyvalues dbo.typ_keyvaluepairstringtablenullable;

INSERT @keyvalues
VALUES ('#\Configuration\Service\Gallery\LargeExtensionUpload\MaxPackageSizeMB\', '40') 

exec prc_UpdateRegistry 1, @keyvalues
```

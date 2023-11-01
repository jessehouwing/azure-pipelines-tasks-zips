# Nuget Tasks that were deprecated from Azure DevOps

> ⚠️ It's highly recommended to migrate your existing pipelines to the newer `NuGetCommand@2` tasks. This extension is provided purely for backwards compatibility.

This extension contains the last versions of the `NuGetInstaller` and `NuGetRestore` tasks which will be removed on 27th of November 2023.

These tasks are installed side-by-side the original tasks

* In UI based builds you can recognize them by the `(Deprecated)` postfix in the name of the task.
* In YAML based builds you can recognize them by the `-deprecated` postfix in the task identifier.

You can use these tasks in case you need more time to transition or if you need these older tasks for older reproducible builds.

## Background:

> [Sprint 229 update - Deprecation announcement for NuGet Restore v1 and NuGet Installer v0 pipeline tasks](https://learn.microsoft.com/en-us/azure/devops/release-notes/2023/sprint-229-update)
> 
> With this update, we are announcing the upcoming deprecation of NuGet Restore v1 and NuGet Installer v0 pipeline tasks. Promptly transition to the NuGetCommand@2 pipeline task to avoid build failure starting on November 27, 2023.
> 
> If you're using the NuGet Restore v1 and NuGet Installer v0 pipeline tasks, promptly transition to the NuGetCommand@2 pipeline task. You'll begin receiving alerts in your pipelines soon if the transition hasn't been made. If no action is taken, starting November 27, 2023, your builds will result in failure.

## Replacing the built-in tasks

An extension is unable to replace the built-in tasks. This is a security feature of the marketplace. But it's possible to replace a task by uploading it directly to your Azure DevOps server.

You can find the [latest version of the task and the scripts to overwrite the built-in tasks in this project's repository](https://github.com/jessehouwing/azure-pipelines-tasks-zips#installation).

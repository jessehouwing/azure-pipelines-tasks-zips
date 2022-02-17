# DotNetCore 6 tasks for Azure DevOps Server

This extension will install the DotNetCore tasks with support for DotNetCore 6 into your Azure DevOps Server.

These tasks are installed side-by-side the original tasks

* In UI based builds you can recognize them by the `(Side-by-side)` postfix in the name of the task.
* In YAML based builds you can recognize them by the `-sxs` postfix in the task identifier.


## Required agent version

You will need to [install a recent agent from the azure-pipelines-agent repository](https://github.com/microsoft/azure-pipelines-agent/releases) for it to auto-detect Visual Studio 2022, or alternatively add the capabilities to the agent manually.

You may need to force Azure DevOps Server to not downgrade back to its preferred agent version. You can do so by setting the following environment variable at the system level on your server before launching the agent:

```
AZP_AGENT_DOWNGRADE_DISABLED=true
```

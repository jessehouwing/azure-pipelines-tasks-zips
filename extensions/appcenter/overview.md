# AppCenter tasks for Azure DevOps Server

This extension will install the latest AppCenterDistribute and AppCenterTest tasks into your Azure DevOps Server.

These tasks are installed side-by-side the original tasks

* In UI based builds you can recognize them by the `(Side-by-side)` postfix in the name of the task.
* In YAML based builds you can recognize them by the `-sxs` postfix in the task identifier.


## Required agent version

You will likely need to [install a more recent agent version from the azure-pipelines-agent repository](https://github.com/microsoft/azure-pipelines-agent/releases).

You may need to force Azure DevOps Server to not downgrade back to its preferred agent version. You can do so by setting the following environment variable at the system level on your server before upgrading the agent:

```
AZP_AGENT_DOWNGRADE_DISABLED=true
```

## Replacing the built-in tasks

An extension is unable to replace the built-in tasks. This is a security feature of the marketplace. But it's possible to replace a task by uploading it directly to your Azure DevOps server.

You can find the [latest version of the task and the scripts to overwrite the built-in tasks in this project's repository](https://github.com/jessehouwing/azure-pipelines-tasks-zips#installation).

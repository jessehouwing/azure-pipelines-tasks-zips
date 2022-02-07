# azure-pipelines-tasks-zips

This repository contains a pre-built version of the built-in tasks or Azure DevOps. In case you need to install an updated version into Team Foundation Server or Azure DevOps Server, you can use these zips.

You can download the tasks from the Releases in this repository. You'll find two kinds of releases.

## mXXX - Releases

These releases contain a verbatim copy of the tasks. They are downloaded directly from my Azure DevOps organisation and are published unchanged.

## mXXX-sxs - Releases

These releases contain a patched copy of the tasks. These tasks can be installed side-by-side with the built-in tasks. All tasks have a new unique id and the task's name has been post-pended with `-sxs`.

# Intallation

To install these tasks into your Team Foundation Server / Azure DevOps Server use:

```
npm install -g tfx-cli
tfx build tasks upload --task-zip-path Task.guid-version.zip --service-url https://yourtfs.com/tfs/DefaultCollection/
```

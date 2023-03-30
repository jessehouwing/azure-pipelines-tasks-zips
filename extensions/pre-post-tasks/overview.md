# Pre and Post job script tasks

This extension contains patched versions of the "BashV3", "CmdLineV2" and "PowerShellV2" tasks. They are built from the latest release/mXXX branch of the [azure-pipelines-tasks](https://github.com/Microsoft/azure-pipelines-tasks) repository.

Each task is extended with a Pre-Job version and a Post-Job version.

## Uses

You can use these tasks to inject an (inline) script that runs prior to checkout (Pre-job), or as part of the cleanup steps of a job (Post-Job).

### Pre-job

The Pre-job tasks can be used to inject a script very early in pipeline. Under normal circumstances, you'd be required to use a custom task or a decorator to do this. 

 * Change variables that influence behavior of the Checkout task. (e.g. `Build.SyncSources`)
 * Install certificates into the git trusted certificates store
 * Replace `git` or `tf` with a different version / configuration 
 * Install an extension to `git` required by your repository
 * Validate certain conditions and fail the build even befor it starts checking out souces

Some of these steps are more useful on the Azure Pipelines Hosted Agents, since you can't change their configuration prior to the job starting.

> Note: since these tasks run prior to checkout, you can't rely on any script files from your repositories. If you want to run a script file, you'll need to first add a tasks that downloads your script using the inline option, then run the script with a second task that runs the script downloaded by the first task.

### Post-Job

The post-job tasks can be used to inject a script that will run after the job has completed.

 * Perform a clean-up task (delete temporary files, trusted certificates etc)
 * Remove gpg sign key from the agent.

## My own uses

I've used these tasks to test scripts I've later included in custom tasks and decorators. That way I did not have to build and publish the extension(s) containing these tasks every time I needed to test something. Examples of my own usage:

 * [Fix parallel pipeline execution of TFVC builds on the hosted pool](https://jessehouwing.net/azure-pipelines-fixing-massive-parallel-builds-with-tfvc/).
 * [Skip Checkout / Don't sync sources task for TFVC](https://github.com/jessehouwing/azure-pipelines-tfvc-tasks/tree/main/tf-vc-dontsync/v2)
 * [Install trusted GPG keys prior to checkout](https://github.com/jessehouwing/azure-pipelines-verify-signed-decorator/blob/main/verify-signed-decorator.yml)

And you can find many other people who included [pre-](https://github.com/search?q=prejobexecution+filename%3Atask.json&type=Code&ref=advsearch&l=&l=) and [post-job](https://github.com/search?q=postjobexecution+filename%3Atask.json&type=Code&ref=advsearch&l=&l=) tasks in their extensions. I'm hoping these tasks will make the job of developing these extensions a little easier. And possibly will remove the need for these kinds of extensions for one-of scripts that need to run outside of the job context.

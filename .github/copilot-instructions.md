# Azure Pipelines Tasks Zips Repository

Azure Pipelines Tasks Zips is a PowerShell-based build system that downloads Azure DevOps pipeline tasks and packages them into direct task zips, side-by-side (sxs) versions with new GUIDs, and Visual Studio marketplace extensions (.vsix files).

Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.

## Working Effectively

### Prerequisites and Dependencies
Install these tools in order before attempting to build:
- `pwsh` (PowerShell Core 7.4+) - REQUIRED for all build scripts
- `7z` (7-zip) - REQUIRED for task zip manipulation: `apt-get install p7zip-full`  
- `npm` and `node` (Node 20+) - REQUIRED for tfx-cli: Install via NodeSource or package manager
- `tfx-cli` - REQUIRED for extension creation: `npm install -g tfx-cli@0.21.3`
- `gh` (GitHub CLI) - REQUIRED for release operations: Install via package manager

### Environment Variables
Set these environment variables before running build scripts:
- `AZURE_DEVOPS_PAT` - Personal Access Token for downloading tasks from Azure DevOps (required for download.ps1)
- `GITHUB_TOKEN` - GitHub token for release operations (required for upload-releases.ps1)
- WITHOUT these tokens, download.ps1 and upload-releases.ps1 will fail

### Build Process Overview
The main build process (build.ps1) orchestrates these scripts in sequence:
1. **download.ps1** - Downloads tasks from Azure DevOps (requires AZURE_DEVOPS_PAT) - takes 5-15 minutes. NEVER CANCEL. Set timeout to 30+ minutes.
2. **generate-sxs.ps1** - Creates side-by-side versions with modified GUIDs/names - takes ~16 seconds per task
3. **generate-deprecated.ps1** - Generates deprecated NuGet task versions - takes ~16 seconds per applicable task  
4. **generate-pre-post.ps1** - Generates pre/post job versions of Bash/CmdLine/PowerShell tasks - takes ~22 seconds per 2 tasks
5. **prepare-extensions.ps1** - Packages tasks into VSIX extensions - takes 30-60 minutes. NEVER CANCEL. Set timeout to 90+ minutes.
6. **upload-releases.ps1** - Uploads to GitHub releases (requires GITHUB_TOKEN)

### Platform Compatibility
**Windows**: All scripts work as-is using paths like `"C:\Program Files\7-Zip\7z.exe"`

**Linux**: Scripts require these modifications for cross-platform compatibility:
- Replace `mkdir "_gen" -force` with `New-Item "_gen" -ItemType Directory -Force`
- Replace `"C:\Program Files\7-Zip\7z.exe"` with `"7z"`
- Replace backslash paths with forward slashes: `"$outputDir\$file"` → `"$($outputDir.FullName)/$file"`

### Essential Build Commands
Run these commands in order for a complete build:

```powershell
# CRITICAL: Set required environment variables first
$env:AZURE_DEVOPS_PAT = "your-azure-devops-pat"
$env:GITHUB_TOKEN = "your-github-token"

# Full build process (Windows-specific paths):
pwsh -File build.ps1  # Takes 45-90 minutes total. NEVER CANCEL. Set timeout to 120+ minutes.

# Individual component testing (Linux-compatible):
pwsh -Command '. ./UUIDv5.ps1; . ./generate-sxs.ps1'      # ~16 seconds per task
pwsh -Command '. ./UUIDv5.ps1; . ./generate-deprecated.ps1' # ~16 seconds per task  
pwsh -Command '. ./UUIDv5.ps1; . ./generate-pre-post.ps1'   # ~22 seconds per 2 tasks

# Extension creation:
pwsh -File prepare-extensions.ps1  # 30-60 minutes. NEVER CANCEL. Set timeout to 90+ minutes.
```

## Validation

### Always Test After Changes
- **NEVER CANCEL long-running builds** - Download takes 5-15 minutes, extension preparation takes 30-60 minutes, full build takes 45-90 minutes
- **Build verification**: Run `pwsh -File build.ps1` and wait for complete success before committing changes
- **Task transformation verification**: Check that generated files in `_gen/` have correctly modified task names, IDs, and friendly names
- **Extension verification**: Verify `.vsix` files are created in `_vsix/` directory and can be listed with `7z l filename.vsix`

### Manual Validation Scenarios
After making changes, always validate these scenarios:
1. **Task transformation**: Extract a generated task zip and verify the `task.json` has new GUID, modified name with "-sxs" suffix, and updated friendlyName
2. **Extension creation**: Create a test extension with `tfx extension create` and verify it packages successfully (~0.4 seconds)
3. **UUID generation**: Run UUIDv5.ps1 and verify it loads without errors (~4 seconds)

### Testing Commands
```powershell
# Verify PowerShell and dependencies
pwsh --version                    # Should be 7.4+
7z                               # Should show 7-zip help
npm --version && node --version  # Should show versions  
tfx --version                    # Should show TFS CLI v0.21.3+
gh --version                     # Should show GitHub CLI version

# Test UUID generation
pwsh -File UUIDv5.ps1           # ~0.6 seconds, should load without errors

# Test task transformation with sample task
# (Create test task zip first, then run transformation scripts)

# Test extension creation
cd extensions/appcenter
tfx extension create --manifests vss-extension.json vss-extension.public.json  # ~0.4 seconds
```

## Common Tasks

### Repository Structure
Key files and directories:
- **build.ps1** - Main orchestration script
- **download.ps1** - Downloads tasks from Azure DevOps 
- **generate-*.ps1** - Transform tasks (sxs, deprecated, pre-post)
- **UUIDv5.ps1** - UUID generation utility (must be sourced before other scripts)
- **prepare-extensions.ps1** - Creates marketplace extensions
- **extensions/** - Extension definitions (appcenter, apple-xcode, dotnetcore, etc.)
- **scripts/install-task.ps1** - PowerShell script for installing individual tasks
- **_download/** - Downloaded task zips (created during build)
- **_gen/** - Generated transformed task zips (created during build)  
- **_vsix/** - Generated extension files (created during build)

### Workflow Integration
The repository uses GitHub Actions (`.github/workflows/publish-tasks.yml`) that:
- Runs on Windows (`windows-latest`)
- Executes the full build process
- Publishes extensions to Visual Studio Marketplace
- Uses secrets: `AZURE_DEVOPS_PAT`, `GITHUB_TOKEN`, `AZURE_MARKETPLACE_PAT`

### Extension Configuration
Extensions are defined in `extensions/*/` directories with:
- **tasks.json** - Lists task names and prefixes/postfixes 
- **vss-extension.json** - Base extension manifest
- **vss-extension.public.json** - Public marketplace settings
- **fix.ps1** - Optional post-processing script
- **overview.md** - Extension description
- Icon files (icon-default.png, icon-large.png)

Available extensions: appcenter, apple-xcode, dotnetcore, generic, nuget-deprecated, pre-post-tasks, visualstudio

### Build Artifacts and Validation
The build process creates these key artifacts:
- **_download/TaskName.guid-version.zip** - Original tasks from Azure DevOps
- **_gen/TaskName-sxs.newguid-version.zip** - Side-by-side versions with new GUIDs
- **_gen/TaskName-deprecated.newguid-version.zip** - Deprecated versions (NuGet tasks only)
- **_gen/Pre-TaskName.newguid-version.zip** - Pre-job versions (Bash/CmdLine/PowerShell)
- **_gen/Post-TaskName.newguid-version.zip** - Post-job versions (Bash/CmdLine/PowerShell)
- **_vsix/jessehouwing.extensionname-version.vsix** - Marketplace extensions

### Critical Validation Steps
After any build, verify these artifacts:
1. **Task transformation verification**: Extract any `-sxs` task and confirm task.json has new GUID and modified name
2. **Extension packaging verification**: List .vsix contents with `7z l filename.vsix` to ensure _tasks directory is included
3. **Build completeness verification**: Check all expected files exist in `_gen/` and `_vsix/` directories

### Task Installation
Install individual tasks using:
```powershell
# Using PowerShell script:
./scripts/install-task.ps1 -CollectionUrl https://yourtfs.com/tfs/DefaultCollection -TaskZip Task.guid-version.zip

# Using tfx-cli:
npm install -g tfx-cli
tfx build tasks upload --task-zip-path Task.guid-version.zip --service-url https://yourtfs.com/tfs/DefaultCollection
```

## Error Handling and Troubleshooting

### Common Build Failures
- **"mkdir: invalid option"** on Linux: Use `New-Item -ItemType Directory -Force` instead of `mkdir -force`
- **"7z command not found"**: Install with `apt-get install p7zip-full` (Linux) or install 7-Zip (Windows)
- **"tfx command not found"**: Install with `npm install -g tfx-cli@0.21.3`
- **HTTP 401 errors during download**: Check `AZURE_DEVOPS_PAT` environment variable
- **GitHub API errors**: Check `GITHUB_TOKEN` environment variable
- **Extension creation failures**: Verify task.json has required fields like `instanceNameFormat`

### Build Time Expectations
- **UUIDv5.ps1 loading**: ~0.6 seconds  
- **Single task transformation**: ~16 seconds
- **Pre/Post generation (2 tasks)**: ~22 seconds  
- **Extension creation**: ~0.4 seconds per extension
- **Full download process**: 5-15 minutes - NEVER CANCEL
- **Extension preparation**: 30-60 minutes - NEVER CANCEL  
- **Complete build**: 45-90 minutes - NEVER CANCEL

### Performance Notes
- Build scripts use PowerShell parallel processing (`ForEach-Object -Parallel`)
- 7-zip operations are throttled to prevent resource exhaustion
- Extension creation processes multiple task versions simultaneously
- Always allow sufficient time for completion - premature cancellation corrupts the build state

### Recovery from Failed Builds
```powershell
# Clean build directories
Remove-Item _download, _gen, _tmp, _vsix -Recurse -Force -ErrorAction SilentlyContinue

# Re-run specific build phases
pwsh -File download.ps1           # Re-download tasks
pwsh -File generate-sxs.ps1       # Re-generate side-by-side versions
pwsh -File prepare-extensions.ps1 # Re-create extensions
```

Always verify environment variables are set before retrying failed builds.
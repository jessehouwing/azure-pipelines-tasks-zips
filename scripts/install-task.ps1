[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CollectionUrl,
    [Parameter(Mandatory = $true)]
    [string]$TaskZip)

$ErrorActionPreference = 'Stop'

# Adapted from: https://github.com/microsoft/azure-pipelines-tasks/tree/master/docs/pinToTaskVersion

function Install-Task {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CollectionUrl,

        [Parameter(Mandatory = $true)]
        $Task)

    "Installing task '$($Task.Name)' version '$($Task.Version)' id '$($Task.Id)'."
    $url = "$($CollectionUrl.TrimEnd('/'))/_apis/distributedtask/tasks/$($Task.Id)/?overwrite=false&api-version=2.0"

    # Format the content.
    [byte[]]$bytes = [System.Convert]::FromBase64String($Task.Base64Zip)

    # Send the HTTP request.
    try {
        Invoke-RestMethod -Uri $url -Method Put -Body $bytes -UseDefaultCredentials -ContentType 'application/octet-stream' -Headers @{
            #'Authorization' = "Basic $([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$Pat")))"
            'X-TFS-FedAuthRedirect' = 'Suppress'
            'Content-Range' = "bytes 0-$($bytes.Length - 1)/$($bytes.Length)"
        }
    } catch {
        $details = $null
        try { $details = ConvertFrom-Json $_.ErrorDetails.Message }
        catch { }

        if ($details.TypeKey -eq 'TaskDefinitionExistsException') {
            Write-Warning $details.Message
        } else {
            throw
        }
    }
}

# Validate the directory exists.
if (!(Test-Path $TaskZip -PathType Leaf)) 
{
    throw "File does not exist: '$TaskZip'."
}

# Resolve the directory info.
$TaskZip = Get-Item $TaskZip


$base64Zip = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Get-Item -LiteralPath $TaskZip).FullName))
$TaskZip.Name

if ($TaskZip.Name -match "(?m)^(?<Name>.*)\.(?<Id>[0-9a-f]{8}[-](?:[0-9a-f]{4}[-]){3}[0-9a-f]{12})-(?<Version>\d+\.\d+\.\d+)\.zip$")
{
    $manifest = $Matches

    # Embed the task into the script.
    $id = "$($manifest.Id)"
    $name = "$($manifest.Name)"
    $version = "$($manifest.Version)"
    $task = @{
        Id = $id.Replace("'", "''")
        Name = $name.Replace("'", "''")
        Version = $version.Replace("'", "''")
        Base64Zip = $base64Zip
    }

    Install-Task -CollectionUrl $CollectionUrl -Task $task
}
else
{
    throw "File does not match required pattern 'name-id.version.zip': '$TaskZip'."
}
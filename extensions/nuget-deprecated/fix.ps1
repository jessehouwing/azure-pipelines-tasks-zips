Get-ChildItem -Recurse -Filter "* *" -Path "./_tasks/" | Rename-Item -NewName { $_.Name -replace " ", "_" }

# Reorder inputs in task.json files so that visibleRule references only point to inputs declared above them
# This is required for publishing tasks to the Visual Studio Marketplace
# Inputs are moved only as far as needed - just above the first input that references them

function Reorder-TaskJsonInputs {
    param (
        [string]$TaskJsonPath
    )
    
    $content = Get-Content -Path $TaskJsonPath -Raw
    $task = $content | ConvertFrom-Json
    
    if (-not $task.inputs -or $task.inputs.Count -eq 0) {
        return
    }
    
    $inputs = [System.Collections.ArrayList]::new(@($task.inputs))
    $inputNames = @($inputs | ForEach-Object { $_.name })
    
    # Iteratively fix ordering issues until none remain
    $maxIterations = $inputs.Count * $inputs.Count  # Prevent infinite loops
    $iteration = 0
    $changed = $true
    
    while ($changed -and $iteration -lt $maxIterations) {
        $changed = $false
        $iteration++
        
        for ($i = 0; $i -lt $inputs.Count; $i++) {
            $currentInput = $inputs[$i]
            
            # Find dependencies from visibleRule
            $deps = @()
            if ($currentInput.visibleRule) {
                $ruleText = $currentInput.visibleRule
                foreach ($inputName in $inputNames) {
                    # Check if this input name appears in the visibleRule as a referenced input
                    if ($ruleText -match "(?:^|[&|]\s*)$([regex]::Escape($inputName))\s*[!=]") {
                        $deps += $inputName
                    }
                }
            }
            
            foreach ($depName in $deps) {
                # Find the position of the dependency
                $depIndex = -1
                for ($j = 0; $j -lt $inputs.Count; $j++) {
                    if ($inputs[$j].name -eq $depName) {
                        $depIndex = $j
                        break
                    }
                }
                
                # If dependency is after this input, move it just before this input
                if ($depIndex -gt $i) {
                    $depInput = $inputs[$depIndex]
                    $inputs.RemoveAt($depIndex)
                    $inputs.Insert($i, $depInput)
                    $changed = $true
                    Write-Host "  Moving '$depName' before '$($currentInput.name)'"
                    break  # Restart the check from the beginning
                }
            }
            
            if ($changed) { break }
        }
    }
    
    if ($iteration -ge $maxIterations) {
        Write-Warning "Max iterations reached for $TaskJsonPath - possible circular dependency"
        return
    }
    
    # Check if order actually changed from original
    $originalInputs = @($task.inputs)
    $orderChanged = $false
    for ($i = 0; $i -lt $originalInputs.Count; $i++) {
        if ($originalInputs[$i].name -ne $inputs[$i].name) {
            $orderChanged = $true
            break
        }
    }
    
    if ($orderChanged) {
        Write-Host "Reordering inputs in: $TaskJsonPath"
        $task.inputs = $inputs.ToArray()
        $task | ConvertTo-Json -Depth 100 | Set-Content -Path $TaskJsonPath -Encoding UTF8
    }
}

# Process all task.json files in _tasks directory
Get-ChildItem -Recurse -Filter "task.json" -Path "./_tasks/" | ForEach-Object {
    Reorder-TaskJsonInputs -TaskJsonPath $_.FullName
}

# Also process task.loc.json files if they exist
Get-ChildItem -Recurse -Filter "task.loc.json" -Path "./_tasks/" | ForEach-Object {
    Reorder-TaskJsonInputs -TaskJsonPath $_.FullName
}

Get-ChildItem -Recurse -Filter "#" -Path "./_tasks/" | %{ 
    $_ | Rename-Item -NewName { $_.Name -replace "#", "_hash_" }

    $indexjs = $_.Parent.FullName + "/index.js"
    if (Test-Path -PathType Leaf -Path $indexjs)
    {
        (gc -raw $indexjs) -replace "\./#","./_hash_" | set-content $indexjs
    }
}
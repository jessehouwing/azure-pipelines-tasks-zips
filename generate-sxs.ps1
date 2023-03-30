$ErrorActionPreference="Stop"

$Source = @"
    using System;
    using System.Security.Cryptography;
    using System.Text;

    public static class UUIDv5
    {
        public static Guid Create(Guid namespaceId, string name)
        {
            if (name == null)
                throw new ArgumentNullException("name");

            // convert the name to a sequence of octets (as defined by the standard or conventions of its namespace) (step 3)
            // ASSUME: UTF-8 encoding is always appropriate
            byte[] nameBytes = Encoding.UTF8.GetBytes(name);

            // convert the namespace UUID to network order (step 3)
            byte[] namespaceBytes = namespaceId.ToByteArray();
            SwapByteOrder(namespaceBytes);

            // comput the hash of the name space ID concatenated with the name (step 4)
            byte[] hash;
            using (HashAlgorithm algorithm =  SHA1.Create())
            {
                algorithm.TransformBlock(namespaceBytes, 0, namespaceBytes.Length, null, 0);
                algorithm.TransformFinalBlock(nameBytes, 0, nameBytes.Length);
                hash = algorithm.Hash;
            }

            // most bytes from the hash are copied straight to the bytes of the new GUID (steps 5-7, 9, 11-12)
            byte[] newGuid = new byte[16];
            Array.Copy(hash, 0, newGuid, 0, 16);

            // set the four most significant bits (bits 12 through 15) of the time_hi_and_version field to the appropriate 4-bit version number from Section 4.1.3 (step 8)
            newGuid[6] = (byte)((newGuid[6] & 0x0F) | (5 << 4));

            // set the two most significant bits (bits 6 and 7) of the clock_seq_hi_and_reserved to zero and one, respectively (step 10)
            newGuid[8] = (byte)((newGuid[8] & 0x3F) | 0x80);

            // convert the resulting UUID to local byte order (step 13)
            SwapByteOrder(newGuid);
            return new Guid(newGuid);
        }

        /// <summary>
        /// The namespace for fully-qualified domain names (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid DnsNamespace = new Guid("6ba7b810-9dad-11d1-80b4-00c04fd430c8");

        /// <summary>
        /// The namespace for URLs (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid UrlNamespace = new Guid("6ba7b811-9dad-11d1-80b4-00c04fd430c8");

        /// <summary>
        /// The namespace for ISO OIDs (from RFC 4122, Appendix C).
        /// </summary>
        public static readonly Guid IsoOidNamespace = new Guid("6ba7b812-9dad-11d1-80b4-00c04fd430c8");

        // Converts a GUID (expressed as a byte array) to/from network order (MSB-first).
        internal static void SwapByteOrder(byte[] guid)
        {
            SwapBytes(guid, 0, 3);
            SwapBytes(guid, 1, 2);
            SwapBytes(guid, 4, 5);
            SwapBytes(guid, 6, 7);
        }

        private static void SwapBytes(byte[] guid, int left, int right)
        {
            byte temp = guid[left];
            guid[left] = guid[right];
            guid[right] = temp;
        }
    }
"@

Add-Type -TypeDefinition $Source -Language CSharp 

$outputDir = mkdir "_gen" -force

$tasksToPatch = get-childitem "_download/*.zip"

foreach ($task in $tasksToPatch)
{
    if (Test-Path "_tmp")
    {
        Remove-Item "_tmp" -force -Recurse
    }

    $taskDir = "_tmp"

    if (Test-Path -path "_gen\$($task.Name -replace '^([^.]+).*-','$1-sxs*')" -PathType Leaf)
    {
        continue
    }

    # Expand-Archive -Path $task -DestinationPath _tmp
    & "C:\Program Files\7-Zip\7z.exe" x $task -o_tmp task*.json *.resjson -r -bd
    if ($LASTEXITCODE -ne 0)
    {
        Remove-item $task
        Write-Error "Failed to extract $task"
        continue
    }

    $taskManifestFiles = @("task.loc.json", "task.json")
    $manifest = @{}

    foreach ($taskManifestFile in $taskManifestFiles)
    {
        $manifestPath = "$taskDir/$taskManifestFile"
        if (Test-Path -Path $manifestPath -PathType Leaf)
        {
            $manifest = (Get-Content $manifestPath -raw) | ConvertFrom-Json -AsHashtable
            $manifest.name = "$($manifest.name)-sxs"
            if ($taskManifestFile -eq "task.json")
            {
                $manifest.friendlyName = "$($manifest.friendlyName) (Side-by-side)"
                if (Test-Path -Path "$taskDir\Strings" -PathType Container)
                {
                    $resourceFiles = Get-ChildItem "$taskDir\Strings\resources.resjson\resources.resjson" -recurse -ErrorAction "Continue"
                    foreach ($resourceFile in $resourceFiles)
                    {
                        $resources = (Get-Content $resourceFile -raw) | ConvertFrom-Json -AsHashtable
                        if ($resources["loc.friendlyName"])
                        {
                            $resources["loc.friendlyName"] = $manifest.friendlyName
                        }
                        $resources | ConvertTo-Json -depth 100 | Out-File $resourceFile -Encoding utf8NoBOM
                    }
                }
            }
            $manifest.id = [UUIDv5]::Create([guid]$manifest.id, [string]$manifest.name).ToString()
            $manifest | ConvertTo-Json -depth 100 | Out-File $manifestPath -Encoding utf8NoBOM
        }
    }

    $taskName = $manifest.name
    $taskid = $manifest.id
    $taskversion = "$($manifest.version.Major).$($manifest.version.Minor).$($manifest.version.Patch)"
    $taskZip = "$taskName.$taskid-$taskversion.zip"

    Copy-Item $task "_gen\$taskzip"
    Push-Location _tmp
    
    & "C:\Program Files\7-Zip\7z.exe" u "$outputDir\$taskzip" "*" -r -bd
    if ($LASTEXITCODE -ne 0)
    {
        Remove-Item "$outputDir\$taskzip"
        Write-Error "Failed to compress $task"
        continue
    }

    write-output "Created: $taskzip"
    Pop-Location
}
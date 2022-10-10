. ./File-Hashing-Utilities.ps1

GenerateFolderHashes -BaseFolderPath @('/mnt/storage/') -ExclusionCriteria @('.*\.plex.*', '.*\.git.*')  -UnhashedFoldersOnly $false -Recurse $true

Write-Host "Done!"
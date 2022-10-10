. ./File-Hashing-Utilities.ps1

VetFolderHashes -BaseFolderPaths @("/mnt/storage/") -ExclusionCriteria @(".*\.plex.*", ".*\.git.*") 

Write-Host "Done!"

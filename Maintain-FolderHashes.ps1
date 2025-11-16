. ./File-Hashing-Utilities.ps1

MaintainFolderHashes -BaseFolderPaths @("/mnt/storage/") -ExclusionCriteria @(".*\.plex.*", ".*\.git.*", "/mnt/storage/Configuration/Docker/.*") 

Write-Host "Done!"

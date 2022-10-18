. ./File-Hashing-Utilities.ps1

MaintainFolderHashes -BaseFolderPaths @("/mnt/storage/") -ExclusionCriteria @(".*\.plex.*", ".*\.git.*") 

Write-Host "Done!"

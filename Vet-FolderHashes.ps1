. ./File-Hashing-Utilities.ps1

VetFolderHashes -BaseFolderPaths @('/mnt/storage/') -PathsToExclude @('.plex')

Write-Host "Done!"

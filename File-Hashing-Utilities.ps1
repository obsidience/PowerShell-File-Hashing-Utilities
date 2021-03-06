
#$ErrorActionPreference = 'Stop'

function GenerateFolderHashes
{
    param(
        [String] $BaseFolderPaths,
        [Boolean] $UnhashedFoldersOnly
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes() started..."
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    UnhashedFoldersOnly: $UnhashedFoldersOnly"

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Gathering folder list..."
    $FolderList = Get-ChildItem $PatherName -Directory -Recurse |
        Where-Object { !$UnhashedFoldersOnly -or -not (Get-ChildItem $_.FullName -File -Force -Filter '.hashes.md5')} | 
        Sort-Object {Get-Random}
    
    for($i = 0; $i -lt $FolderList.length; $i++)
    {
        $Folder = $FolderList[$i]

        Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($($i) of $($FolderList.Length))"
        $FileHashes = @{}

        $FileList = Get-ChildItem $Folder -File

        for($j = 0; $j -lt $FileList.length; j++)
        {
            $File = $FileList[$j]

            Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($($j) of $($FileList.Length))"
            $Hash = (Get-FileHash $File -Algorithm MD5)
            $FileHashes.Add($File, $Hash)
        }

        if($FileHashes.Count -gt 0)
        {
            $OutFilePath = "$($Folder.FullName)/.hashes.md5"
            $FileHashes.GetEnumerator() | Sort-Object {$_.key.Name} | ForEach-Object {$_.value.Hash.ToUpper() + " *" + $_.key.Name} | Out-File -FilePath $OutFilePath        
        }
        else {
            Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Skipping..."
        }
    }

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes() finished!"
}

function GetHashFiles
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $PathsToExclude
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles()"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    PathsToExclude: $PathsToExclude"

    $HashFiles = Get-ChildItem $BaseFolderPaths -File -Force -Recurse -Filter ".hashes.md5" -Exclude $PathsToExclude
    return $HashFiles
}

function VetFolderHashes
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $PathsToExclude
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() started..."
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    PathsToExclude: $PathsToExclude"

    $HashFiles = GetHashFiles -BaseFolderPaths $BaseFolderPaths -PathsToExclude $PathsToExclude

    for($i = 0; $i -lt $HashFiles.length; $i++)
    {
        $File = $HashFiles[$i]

        Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing file `"$($File.FullName)`"... ($($i) of $($HashFiles.Length))"
        Write-Host "..."
    }

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() finished!"
}
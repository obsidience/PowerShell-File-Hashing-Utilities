
#$ErrorActionPreference = 'Stop'

function GenerateFolderHashes
{
    param(
        [String] $BaseFolderPath,
        [Boolean] $UnhashedFoldersOnly
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes()"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPath: $BaseFolderPath"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    UnhashedFoldersOnly: $UnhashedFoldersOnly"

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Gathering folder list..."
    $FolderList = Get-ChildBaseItem $PatherName -Directory -Recurse |
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
}

function GetHashFiles
{
    param(
        [String] $BaseFolderPath
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles()"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPath: $BaseFolderPath"

    $HashFiles = Get-ChildItem $BaseFolderPath -File -Recurse -Include .hashes.md5
    return $HashFiles
}

function VetFolderHashes
{
    param(
        [String] $BaseFolderPath
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes()"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPath: $BaseFolderPath"

    $HashFiles = GetHashFiles -BaseFolderPath $BaseFolderPath

    Write-Host "..."
}
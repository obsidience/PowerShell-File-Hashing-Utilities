
#$ErrorActionPreference = 'Stop'

function GenerateFolderHashes
{
    param(
        [String] $FolderName,
        [Boolean] $UnhashedFoldersOnly
    )

    $FolderList = Get-ChildItem $FolderName -Directory -Recurse |
        Where-Object { !$UnhashedFoldersOnly -or -not (Get-ChildItem $_.FullName -File -Force -Filter '.hashes.md5')} | 
        Sort-Object {Get-Random}
    
    for($i = 0; $i -lt $FolderList.length; $i++)
    {
        $Folder = $FolderList[$i]

        Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($(i) of $($FolderList.Length))"
        $FileHashes = @{}

        $FileList = Get-ChildItem $Folder -File

        for($j = 0; $j -lt $FileList.length; j++)
        {
            $File = $FileList[$j]

            Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($(i) of $($FileList.Length))"
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


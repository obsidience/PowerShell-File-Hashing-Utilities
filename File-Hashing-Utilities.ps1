
#$ErrorActionPreference = 'Stop'

function GenerateFolderHashes
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $ExclusionCriteria,
        [Boolean] $UnhashedOnly,
        [Boolean] $Recurse
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes() started..."
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    UnhashedOnly: $UnhashedOnly"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Gathering folder list..."
    $FoldersToProcess = GetFoldersToProcess -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -UnhashedOnly $UnhashedOnly -Recurse $Recurse
    
    for($i = 0; $i -lt $FoldersToProcess.Count; $i++)
    {
        $Folder = $FoldersToProcess[$i]

        Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($($i) of $($FoldersToProcess.Count))"
        $FileHashes = @{}

        $FileList = Get-ChildItem $Folder -File

        for($j = 0; $j -lt $FileList.Count; j++)
        {
            $File = $FileList[$j]

            Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($($j) of $($FileList.Count))"
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

function VetFolderHashes
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $ExclusionCriteria
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() started..."
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"

    # step 1 - create hashes for folders that have yet to be hashed
    #GenerateFolderHashes -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -UnhashedOnly $true -Recurse $true
    # step ? - find invalid hashes, such as folders with no files
    
    # step 2 - verify existing hashes by processing the oldest first

    # $HashFiles = GetHashFiles -BaseFolderPaths $BaseFolderPaths -ExclusionCriteria $ExclusionCriteria

    # for($i = 0; $i -lt $HashFiles.Count; $i++)
    # {
    #     $File = $HashFiles[$i]

    #     Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing file `"$($File.FullName)`"... ($($i) of $($HashFiles.Count))"
    #     Write-Host "..."
    # }

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() finished!"
}

function GetFoldersToProcess
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $ExclusionCriteria,
        [Boolean] $UnhashedOnly,
        [Boolean] $Recurse
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetFoldersToProcess() started..."
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    UnhashedOnly: $UnhashedOnly"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

    $FoldersToProcess = Get-ChildItem -Path $BaseFolderPaths -Directory -Recurse:$Recurse -Verbose |
        Where-Object { 
            ($_.FullName -notmatch $($ExclusionCriteria -join "|")) -and # folders that aren't excluded or inside excluded 
            (!($UnhashedOnly) -or !(Get-ChildItem -Path $_.FullName -File -Force -Filter '.hashes.md5')) -and # only folders without hashes, unless the unhashedonly option is passed
            ((Get-ChildItem -Path $_.FullName -File).Count -gt 0) # only folders with files in them
            
        } | 
        Sort-Object {Get-Random}
    
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetFoldersToProcess() finished!"
    return $FoldersToProcess
}

function GetHashFiles
{
    param(
        [String[]] $BaseFolderPaths,
        [String[]] $ExclusionCriteria
    )

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles()"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"

    $HashFiles = Get-ChildItem -Path $BaseFolderPaths -File -Force -Recurse -Filter ".hashes.md5" |
        Where-Object { 
            ($_.FullName -notmatch $($ExclusionCriteria -join "|")) # folders that aren't excluded or inside excluded 
        }

    Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles() finished!"
    return $HashFiles
}
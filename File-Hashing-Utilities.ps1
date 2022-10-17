
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
		$FileHashes = @{}
		$Files = Get-ChildItem $Folder -File

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($($i + 1) of $($FoldersToProcess.Count))"

		for($j = 0; $j -lt $Files.Count; $j++)
		{
			$File = $Files[$j]

			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($($j + 1) of $($Files.Count))"
			$HashValue = (Get-FileHash $File -Algorithm MD5).Hash
			$FileHashes.Add($File.Name, $HashValue)
		}

		if($FileHashes.Count -gt 0)
		{
			$OutFilePath = "$($Folder.FullName)/.hashes.md5"
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Writing file `"$($OutFilePath)`"..."

			$FileHashes.GetEnumerator() | 
				Sort-Object {$_Key} | 
				ForEach-Object {
					$_.Value.ToUpper() + " *" + $_.Key
				} | Out-File -FilePath $OutFilePath        
		}
		else {
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Skipping..."
		}
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes() finished!"
}

function RefreshFolderHashes
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria,
		[Boolean] $Recurse
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VerifyFolderHashes() started..."
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

	$HashesFilesToProcess = GetHashFiles -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $Recurse

	for($i = 0; $i -lt $HashesFilesToProcess.Count; $i++)
	{
		$HashFile = $HashesFilesToProcess[$i]
		$Folder = $HashFile.Directory
		$Files = (Get-ChildItem -Path $("$($HashFile.DirectoryName)\\*") -File -Force -Exclude "*.md5")
		$FileHashes = ParseHashFile $HashFile
		$RefreshNeeded = $false

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($($i + 1) of $($HashesFilesToProcess.Count))"

		for($j = 0; $j -lt $Files.Count; $j++)
		{
			$File = $Files[$j]
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($($j + 1) of $($Files.Count))"

			$HashValue = (Get-FileHash $File -Algorithm MD5)
			if($HashValue.Hash -ne $FileHashes[$File.Name])
			{
				$RefreshNeeded = $true
				$FileHashes[$File.Name] = $HashValue.Hash
			}
		}

		if($RefreshNeeded)
		{
			$OutFilePath = "$($Folder.FullName)/.hashes.md5"
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Writing file `"$($OutFilePath)`"..."

			$FileHashes.GetEnumerator() | 
				Sort-Object {$_.Key} | 
				ForEach-Object {
					$_.Value.ToUpper() + " *" + $_.Key
				} | 
				Out-File -FilePath $OutFilePath
		}
		else { Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashes good, skipping..." }
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VerifyFolderHashes() finished!"
}

function InvalidateBadHashes
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria,
		[Boolean] $Recurse
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] InvalidateBadHashes() started..."
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

	$HashesToProcess = GetHashFiles -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $Recurse

	for($i = 0; $i -lt $HashesToProcess.Count; $i++)
	{
		$Hash = $HashesToProcess[$i]
		$Folder = $Hash.DirectoryName
		$Files = (Get-ChildItem -Path $("$Folder\\*") -File -Force -Exclude "*.md5")
		$FileHashes = ParseHashFile $Hash
		$IsBad = $false

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder)`"... ($($i) of $($HashesToProcess.Count))"

		# invalidate hashes with file count mismatch
		if($FileHashes.Count -ne $Files.Count) { $IsBad = $true; }
		else
		{
			foreach($File in $Files)
			{
				# invalidate hashes with files newer than the hash
				if($File.LastWriteTime -gt $Hash.LastWriteTime) { $IsBad = $true; break; }

				# invalidate hashes with file name mismatch
				if($FileHashes[$File.Name] -eq $null) { $IsBad = $true; break; }
			}
		}

		if($IsBad)
		{
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Removing bad hash file `"$($Hash.FullName)`"..."
			Remove-Item -Path $Hash.FullName -Force -WhatIf
		}
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] InvalidateBadHashes() finished!"
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

	# step 1 - find invalid hashes without verifying hash
	#InvalidateBadHashes -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $true

	# step 2 - create hashes for folders that have yet to be hashed
	#GenerateFolderHashes -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -UnhashedOnly $true -Recurse $true
	
	# step 3 - vet and refresh all existing hashes
	RefreshFolderHashes  -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $true

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
		[String[]] $ExclusionCriteria,
		[Boolean] $Recurse
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles()"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"

	$HashFiles = Get-ChildItem -Path $BaseFolderPaths -File -Force -Recurse:$Recurse -Filter ".hashes.md5" |
		Select-Object -First 20 |
		Where-Object { 
			($_.FullName -notmatch $($ExclusionCriteria -join "|")) # folders that aren't excluded or inside excluded 
		} 


	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles() finished!"
	return $HashFiles
}

function ParseHashFile
{
	param(
		[String] $HashFile
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] ParseHashFile() started..."
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    HashFile: $HashFile"

	$FileHashes = @{}
	$(Get-Content $HashFile) | ForEach-Object {
		$value, $key = ($_).Split(" *")
		$FileHashes[$key] = $value
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] ParseHashFile() finished!"
	return $FileHashes
}
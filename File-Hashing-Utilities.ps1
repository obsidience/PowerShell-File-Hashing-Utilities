
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

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Gathering list of folders..."
	$FoldersToProcess = GetFoldersToProcess -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -UnhashedOnly $UnhashedOnly -Recurse $Recurse
	
	for($i = 0; $i -lt $FoldersToProcess.Count; $i++)
	{
		$Folder = $FoldersToProcess[$i]
		$Hashes = @{}
		$Files = Get-ChildItem $Folder -File

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] Processing folder `"$($Folder.FullName)`"... ($($i + 1) of $($FoldersToProcess.Count))"

		for($j = 0; $j -lt $Files.Count; $j++)
		{
			$File = $Files[$j]

			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashing file `"$($File.Name)`"... ($($j + 1) of $($Files.Count))"
			$HashValue = (Get-FileHash -LiteralPath $File -Algorithm MD5).Hash
			$Hashes.Add($File.Name, $HashValue)
		}

		if($Hashes.Count -gt 0)
		{
			$OutFilePath = "$($Folder.FullName)/.hashes.md5"
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Writing file `"$($OutFilePath)`"..."

			WriteHashFile -Hashes $Hashes -FilePath $OutFilePath
		}
		else {
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Skipping..."
		}
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GenerateFolderHashes() finished!"
}

function MaintainFolderHashes
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() started..."
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"

	# step 1 - find invalid hashes for folders with changes
	InvalidateHashesWithFolderChanges -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $true

	# step 2 - generate hashes for folders without them
	GenerateFolderHashes -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -UnhashedOnly $true -Recurse $true
	
	# step 3 - vet and refresh all existing hashes
	VetAndRefreshExistingHashes  -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $true

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VetFolderHashes() finished!"
}

function VetAndRefreshExistingHashes
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

	$HashFilesToProcess = GetHashFiles -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $Recurse

	for($i = 0; $i -lt $HashFilesToProcess.Count; $i++)
	{
		$HashFile = $HashFilesToProcess[$i]
		$Folder = $HashFile.Directory
		$Files = (Get-ChildItem -Path $("$($HashFile.DirectoryName)\\*") -File -Force -Exclude "*.md5")
		$Hashes = ParseHashFile $HashFile
		$RefreshNeeded = $false

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Processing folder `"$($Folder.FullName)`"... ($($i + 1) of $($HashFilesToProcess.Count))"

		for($j = 0; $j -lt $Files.Count; $j++)
		{
			$File = $Files[$j]
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       Hashing file `"$($File.Name)`"... ($($j + 1) of $($Files.Count))"

			$HashValue = (Get-FileHash -LiteralPath $File -Algorithm MD5)
			if($HashValue.Hash -ne $Hashes[$File.Name])
			{
				$RefreshNeeded = $true
				$Hashes[$File.Name] = $HashValue.Hash
			}
		}

		if($RefreshNeeded)
		{
			$OutFilePath = "$($Folder.FullName)/.hashes.md5"
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       Writing file `"$($OutFilePath)`"..."

			WriteHashFile -Hashes $Hashes -FilePath $OutFilePath
		}
		else { Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       Hashes good, skipping..." }
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] VerifyFolderHashes() finished!"
}

function InvalidateHashesWithFolderChanges
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria,
		[Boolean] $Recurse
	)

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] InvalidateHashesWithFolderChanges() started..."
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Gathering list of hash files..."
	$HashFilesToProcess = GetHashFiles -BaseFolderPath @BaseFolderPaths -ExclusionCriteria $ExclusionCriteria -Recurse $Recurse

	for($i = 0; $i -lt $HashFilesToProcess.Count; $i++)
	{
		$Hash = $HashFilesToProcess[$i]
		$Folder = $Hash.DirectoryName
		$Files = (Get-ChildItem -Path $("$Folder\\*") -File -Force -Exclude "*.md5")
		$Hashes = ParseHashFile $Hash
		$IsBad = $false

		Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Processing folder `"$($Folder)`"... ($($i + 1) of $($HashFilesToProcess.Count))"

		# invalidate hashes with file count mismatch
		if($Hashes.Count -ne $Files.Count) 
		{ 
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       File count mismatch, invalidating hash..."
			$IsBad = $true; 
		}
		else
		{
			foreach($File in $Files)
			{
				# invalidate hashes with files newer than the hash
				if($File.LastWriteTime -gt $Hash.LastWriteTime) 
				{ 
					Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       $($File) has been updated, invalidating hash..."
					$IsBad = $true; 
					break; 
				}

				# invalidate hashes with file name mismatch
				if($Hashes[$File.Name] -eq $null)
				{ 
					Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       $($File) not found, invalidating hash..."
					$IsBad = $true; 
					break; 
				}
			}
		}

		if($IsBad)
		{
			Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]       Removing bad hash file `"$($Hash.FullName)`"..."
			Remove-Item -Path $Hash.FullName -Force
		}
	}

	Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] InvalidateHashesWithFolderChanges() finished!"
}

function GetFoldersToProcess
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria,
		[Boolean] $UnhashedOnly,
		[Boolean] $Recurse
	)

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetFoldersToProcess() started..."
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    UnhashedOnly: $UnhashedOnly"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Recurse: $Recurse"

	$FoldersToProcess = Get-ChildItem -Path $BaseFolderPaths -Directory -Recurse:$Recurse -Verbose |
		Where-Object { 
			($_.FullName -notmatch $($ExclusionCriteria -join "|")) -and # folders that aren't excluded or inside excluded 
			(!($UnhashedOnly) -or !(Get-ChildItem -Path $_.FullName -File -Force -Filter '.hashes.md5')) -and # only folders without hashes, unless the unhashedonly option is passed
			((Get-ChildItem -Path $_.FullName -File).Count -gt 0) # only folders with files in them
			
		} | 
		Sort-Object {Get-Random}
	
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetFoldersToProcess() finished!"
	return $FoldersToProcess
}

function GetHashFiles
{
	param(
		[String[]] $BaseFolderPaths,
		[String[]] $ExclusionCriteria,
		[Boolean] $Recurse
	)

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles()"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    BaseFolderPaths: $BaseFolderPaths"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    ExclusionCriteria: $ExclusionCriteria"

	$HashFiles = Get-ChildItem -Path $BaseFolderPaths -File -Force -Recurse:$Recurse -Filter ".hashes.md5" |
		#Select-Object -First 20 |
		Where-Object { 
			($_.FullName -notmatch $($ExclusionCriteria -join "|")) # folders that aren't excluded or inside excluded 
		} | 
		Sort-Object {Get-Random}


	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] GetHashFiles() finished!"
	return $HashFiles
}

function ParseHashFile
{
	param(
		[String] $HashFile
	)

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] ParseHashFile() started..."
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    HashFile: $HashFile"

	$Hashes = @{}
	$(Get-Content $HashFile) | ForEach-Object {
		$value, $key = ($_).Split(" *")
		$Hashes[$key] = $value
	}

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] ParseHashFile() finished!"
	return $Hashes
}

function WriteHashFile
{
	param(
		[Hashtable] $Hashes,
		[String] $FilePath
	)

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] WriteHashFile()"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    Hashes: $Hashes"
	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")]    FilePath: $FilePath"

	# if($Hashes -eq $null -or $Hashes.Count -eq 0)
	# {
	# 	$x = 0;
	# }

	$Hashes.GetEnumerator() | 
				Sort-Object {$_.Key} | 
				ForEach-Object {
					# if($_.Value -eq $null -or $_.Key -eq $null)
					# {
					# 	$x = 0;
					# }

					$_.Value.ToUpper() + " *" + $_.Key
				} | 
				Out-File -FilePath $OutFilePath

	# Write-Host "[$(Get-Date -format "yyyy-MM-dd HH:mm:ss")] WriteHashFile() finished!"
}
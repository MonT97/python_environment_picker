#? The config file is created during the tool installation

function script:cfg_Configure {
	param(
		[string]$path,
		[parameter(Mandatory)]
		[string]$instPath,
		[parameter(Mandatory)]
		[string]$cfgFileName
	)
	Write-Host " >> Config mode:"
	if (Test-Path $path) {
		Write-Host " >> Valid path [$path]"
		$private:configFilePath = $(Join-Path $instPath $cfgFileName)
		$private:rawConfig = Get-Content $private:configFilePath -Raw |ConvertFrom-Json
		$script:installationPath = $private:rawConfig.installation_path
		$private:rawConfig.old_default_environments_path = $private:rawConfig.default_environments_path
		$private:rawConfig.default_environments_path = $path
		$private:rawConfig | ConvertTo-Json > $private:configFilePath
		Write-Host " >> Default path [$($private:rawConfig.old_default_environments_path)] changed to [$path]"
	} else {
		Write-Error " <!> The provided path is invalid or doesn't exist!"
	}
}

function cfg_Uninstall {
	param(
		[parameter(Mandatory)]
		[string]$instPath
	)
	Write-Host " >> Uninstalling tool from path [$instPath]"
	do {
		[string]$private:deleteFlag = Read-Host (" >> Delete configuration?, default environments path, etc`n [y|n] > ").ToLower()
		$private:inpFlag = $private:deleteFlag -notmatch '^y$|^n$'
		if ($private:inpFlag) {
			Write-Host " >> Invalid input"
		}
	} while ($private:inpFlag)
	switch -Regex ($private:deleteFlag) {
		('^y$') {
			Remove-Item -Recurse -Force $instPath
			Remove_From_PATH -instPath $script:installationPath
		}
		('^n$') {
			Remove-Item -Recurse $instPath -Exclude *.json
			Remove_From_PATH -instPath $script:installationPath
		}
	}
	Write-Host " >> Tool uninstalled successfully!"
}

function script:Remove_From_PATH {
	param(
		[parameter(Mandatory)]
		[string]$instPath
	)
	[bool]$private:addedToPath = (
        [System.Environment]::GetEnvironmentVariable('path', 'user') -like "*$instPath*")
	if ($private:addedToPath) {
		$private:oldPATH = [System.Environment]::GetEnvironmentVariable('path', 'user')
		$private:splitOldPATH = $private:oldPATH.Split(";")
		$private:newPATH = $($private:splitOldPATH | Where-Object {$_ -ne $instPath}) -join(";")
		[System.Environment]::SetEnvironmentVariable('path', $private:newPATH, 'user')
	}
}
function script:cfg_Configure {
	param(
		[string]$path,
		[parameter(Mandatory)]
		[string]$instPath,
		[parameter(Mandatory)]
		[string]$cfgFileName
	)
	Write-Host " >> Config mode:"
	if ((Test-Path $local:path)) {
		Write-Host " >> Valid path [$local:path]"
		$private:configFilePath = $(Join-Path $instPath $cfgFileName)
		$private:rawConfig = Get-Content $private:configFilePath -Raw |ConvertFrom-Json
		$private:rawConfig.old_default_path = $private:rawConfig.default_path
		$private:rawConfig.default_path = $local:path
		$private:rawConfig | ConvertTo-Json > $private:configFilePath
		Write-Host " >> Default path [$($private:rawConfig.old_default_path)] changed to [$local:path]"
	} else {
		Write-Error " <!> The provided path is invalid or doesn't exist!"
		exit
	}
}

function cfg_Uninstall {
	param(
		[parameter(Mandatory)]
		[string]$instPath
	)	
	Write-Host " >> Uninstalling tool from path [$instPath]"
	[string]$private:deleteFlag = Read-Host " >> Delete configuration?, default environment path, etc`n [y|n] > "
	switch -Regex ($private:deleteFlag.ToLower()) {
		("^y$") {
			Remove-Item -Recurse $instPath*
		}
		("^n$") {
			Remove-Item -Recurse $instPath -Exclude *.json
		}
		Default {
			Write-Host " >> Invalid input"
			cfg_Uninstall -instPath $instPath
		}
	}
	Write-Host " >> Tool uninstalled successfully!"
}
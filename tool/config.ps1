function script:cfg_Configure {
	param(
		[string]$path,
		[parameter(Mandatory)]
		[string]$instPath,
		[parameter(Mandatory)]
		[string]$cfgFileName
	)
	Write-Host " >> Entered config mode."
	if ((Test-Path $local:path)) {
		Write-Host " >> Valid path [$local:path]"
		$private:configFilePath = $(Join-Path $instPath $cfgFileName)
		$private:rawConfig = Get-Content $private:configFilePath -Raw |ConvertFrom-Json
		$private:rawConfig.old_default_path = $private:rawConfig.default_path
		$private:rawConfig.default_path = $local:path
		$private:rawConfig | ConvertTo-Json > $private:configFilePath
		Write-Host " >> Default path [$($private:rawConfig.old_default_path)] changed to [$local:path]"
	} else {
		Write-Error "<!> Path invalid or doesn't exist!"
		exit
	}
}

function cfg_Uninstall {
	param(
		[string]$path
	)	
	Write-Host " !> uninstalling tool from path [$path]"
}
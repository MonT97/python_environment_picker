function script:cfg_Configure {
	param(
		[string]$path
	)
	Write-Host " >> Entered config mode."
	if ((Test-Path $local:path)) {
		Write-Host " >> Valid path [$local:path]"
		$private:configFilePath = $(Join-Path $psHome '/.penv_config.json')
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

function script:cfg_Look_For_Config_File {
	param(
		[Parameter(Mandatory)]
		[string]$path
	)
	[bool]$private:configFileNotFound = !(Test-Path $local:path)
	if ($private:configFileNotFound) {
		#! The used shouldn't know about the internal workings, so no "config file not found" massaga
		Write-Host "`n !> No default envronments path is provided."
		$private:environmentPath = Read-Host " !> Provide The evnironments path:`n >"
		if (Test-Path $private:environmentPath) {
			cfg_Create_Config_File -envsPath $private:environmentPath -path $local:path	
		}
		Write-Host " <!> invalid path!"
		cfg_Look_For_Config_File -path $path
	}
}

function script:cfg_Create_Config_File {
	param(
		[parameter(Mandatory)]
		[string]$envsPath,
		[parameter(Mandatory)]
		[string]$path
		)
		New-Item -ItemType File $path | Out-Null
		$local:config = ConvertTo-Json @{
			self_path = $path
			default_path = $envsPath
			old_default_path = $envsPath
		}
		$local:config > $path
		$local:configFromFile = Get-Content $local:path | ConvertFrom-Json
		Write-Host ">>> $local:configFromFile"
		Write-Host " !> Created config file at [$path]."
		Write-Host " !> New default path is [$($local:configFromFile.default_path)].`n"
}

function cfg_Uninstall {
	param(
		[string]$path
	)	
	Write-Host " !> uninstalling tool from path [$path]"
}
function script:cfg_Config {
	param(
		[string]$path
	)
	if ([bool]$local:path){
		if ((Test-Path $local:path) -and (($local:path) -match ('.*/.*|.*\.*'))) {
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
		
	}

function script:cfg_Look_For_Config_File {
	param(
		[Parameter(Mandatory)]
		[string]$path
	)
	[bool]$private:configNotFound = !(Test-Path $local:path)
	if ($private:configNotFound) {
		# TODO: check user input!
		Write-Host "`n !> No default envronments path is provided."
		$private:environmentPath = Read-Host " !> Provide The evnironments path:`n >"
		cfg_Create_Config_File -envsPath $private:environmentPath -path $local:path	
	}
}

function script:cfg_Create_Config_File {
	param(
		[string]$envsPath,
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
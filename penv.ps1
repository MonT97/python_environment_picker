param(
	[string]$script:envName,
	[bool]$script:newSession = $true
)

function script:Main {
	Initiate_Variables
	[string]$private:greet = Parse_Greet -path $script:defaultPath
	Write-Output $private:greet
	if ($script:isEnvironmentNew) {
		Create_New_Environment -envName $script:envName -newEnvPath $script:newEnvironmentPath 
	} else {
		Pick_Environment
	}
}

function script:Initiate_Variables {
	[string]$local:configFileName = ".penv_config.json"
	[string]$local:configFilePath = $(Join-Path $psHome $local:configFileName)
	Look_For_Config_File -path $local:configFilePath
	[string]$script:workingDir = Get-Location
	[string]$script:defaultPath = $(Get-Content $local:configFilePath -Raw |ConvertFrom-Json).default_path
	[string]$script:newEnvironmentPath = Join-Path $script:defaultPath $script:envName
	[bool]$script:isEnvironmentNew = (
		!(Test-Path $script:newEnvironmentPath) -and ($script:envName)
		)
	}
	
function script:Look_For_Config_File {
	param(
		[Parameter(Mandatory)]
		[string]$path
	)
	[bool]$private:configNotFound = !(Test-Path $local:path)
	if ($private:configNotFound) {
		# TODO: check user input!
		Write-Host "`n !> No default envronments path is provided."
		$private:environmentPath = Read-Host " !> Provide The evnironments path:`n >"
		Create_Config_File -envsPath $private:environmentPath -path $local:path	
	}
}

function script:Create_Config_File {
	param(
		[string]$envsPath,
		[string]$path
		)
		New-Item -ItemType File $path | Out-Null
		$local:config = ConvertTo-Json @{
			default_path = $envsPath
		}
		# TODO: Check for match pre and post JSONing
		$local:config > $path
		$local:configFromFile = Get-Content $local:path | ConvertFrom-Json
		Write-Host ">>> $local:configFromFile"
		Write-Host " !> Created config file at [$path]."
		Write-Host " !> New default path is [$($local:configFromFile.default_path)].`n"
}

function script:Parse_Greet {
	param(
		[string]$path
	)
	[string]$private:greet =  "
       __      __     _________     ____     __   ____________
      |  \    /  |   |   ___   |   |    \   |  | |____    ____|
      |   \__/   |   |  |   |  |   |  |\ \  |  |      |  |   
      |          |   |  |   |  |   |  | \ \ |  |      |  |
      |  |\__/|  |   |  |   |  |   |  |  \ \|  |      |  |
      |  |    |  |   |  |   |  |   |  |   \ |  |      |  |
      |  |    |  |   |  |___|  |   |  |    \   |      |  |
      |__|    |__|   |_________|   |__|     \__|      |__|
  	
/==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==\
|                    Python Environment Picker                     |
\==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==/

 > The specified path is:
   [$path]
 > To change the specified path call with the one you want:
   penv [EXAMPLE/PATH/etc] # TDOD

|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|"
	return $greet
}

function script:Quit {
	Set-Location $Home
	Write-Output " > Quitting ...`n"
	Write-Output "|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n`n"
	exit
}

function script:Create_New_Environment {
	param(
		[parameter(Mandatory)]
		[string]$envName,
		[parameter(Mandatory)]
		[string]$newEnvPath
	)
	$private:pickFlag = Read-Host " > Create new [$envName] at [$newEnvPath]??
   [y|q(uit)]`n >"
	$private:pickFlag = $private:pickFlag.ToLower()
	
	switch -Regex ($private:pickFlag) {
		('^y$|^$') {
			Write-Output " > Creating Environment [$envName] ... `n"
			try {
				py -m venv $newEnvPath
			} catch {
				Write-Error " <!> Environment creation failed.`n[py -m venv `$newEnvPath]
 $PsItem.ScriptStackTrace"
				Quit
			}
			[bool]$private:envCreated = $(test-path $newEnvPath)
			Write-Output " > environment [$envName] created [$envCreated]`n"
			if ($script:newSession) {
				New-Item -ItemType directory $(Join-Path $newEnvPath "projs") | Out-Null
				Handle_Session -path $newEnvPath
			}
			Set-Location $newEnvPath
		}
		('^q$') {
			Quit
		}
		default {
			Write-Output " > Invalid iput[$private:pickFlag]`n >"
			Create_New_Environment -envName $envName -newEnvPath $newEnvPath
		}
	}
}

function script:Activate_Environment {
	param(
		[Parameter(Mandatory)]
		[string]$path
	)
	Set-Location $(Join-Path $path "Scripts")
	./activate
	Set-Location $(Join-Path $path "projs")
}

function script:Handle_Session {
	param(
		[parameter(Mandatory)]
		[string]$path
	)
	Write-Host $path
	$private:pickFlag = Read-Host " >:
 > Lunch in:
 >> VsCode -------- [v]
 >> Jupyter-lab --- [j]
 > Activate environment -- [o]
 > Quit ------------------ [q]`n >"
	$pickFlag = $pickFlag.ToLower()

	Activate_Environment -path $path

	function local:Create_Shell_Instance {
		Write-Output " > Lunching Jupyter-lab ..."
		[string]$private:snippet = "
		Set-Location Join-Path $path `"Scripts`"
		./activate
		Set-Location Join-Path $path `"projs`""
		start-process powershell -ArgumentList ("-noexit", "-c &{$snippet}")
	}

	switch -Regex ($pickFlag) {
		('^o$') {
			Set-Location $pwd
		}
		('^q$') {
			deactivate
			Quit
		}
		('^v$') {
			code .
			break
		}
		('^j$') {
			[string]$private:packagePath = Join-Path $path "lib" "site-packages"
			[bool]$private:noJupyter = !('jupyter' -in $(Get-ChildItem $packagePath))
			if ($noJupyter) {
				Write-Output " > Jupyter isn't installed.`n
 > Installing Jupyter-lab ....`n"
				pip install jupyterlab --quiet
			}
			Create_Shell_Instance
			jupyter-lab
		}
		default {
			Write-Output " > Invalid iput[$pickFlag]`n >"
			Handle_Session -path $path
		}
	}
}

function script:Refresh_Environment {
	param(
		[Parameter(Mandatory)]
		[string]$envsPath,
		[Parameter(Mandatory)]
		[string]$envName
	)
	[string]$private:refreshFlag = (
		Read-Host " > refresh [$envName] at [$envsPath]??`n [y|n|q(uit)]`n >"
		).ToLower()
	
	switch -Regex ($private:refreshFlag) {
		('^y$|^$') {
			[string]$private:originalEnvPath = Join-Path $envsPath $envName
			[string]$private:backupPath = Join-Path $envsPath ".$envName"

			Write-Host " > Creating backup ..."
			try {
				Copy-Item -r $private:originalEnvPath $private:backupPath 
			} catch {
				Write-Error " <!> Something went wrong, couldn't create the backup!.
 $PsItem.ScriptStackTrace"
				Remove-Item -r $private:backupPath
				Refresh_Environment -envsPath $envsPath -envName $envName
			}
			Activate_Environment -path $private:originalEnvPath
			Set-Location $envsPath
			try {
				pip freeze > Join-Path $private:backupPath ".libs.txt"
			}
			catch {
				Write-Error " <!> Couldn't create pip [requirement.txt] file at [$private:backupPath/.libs.txt]!.`n $PsItem.ScriptStackTrace`n >> Backup .[$envName] at [$private:backupPath] <<"
				Set-Location $(Join-Path $private:originalEnvPath "Scripts")
				deactivate
				Set-Location $envsPath
				Remove-Item -r $private:backupPath
				Pick_Environment
			}
			Remove-Item -r $private:originalEnvPath
			try {
				" > Refreshing ..."
				py -m venv $private:originalEnvPath
			} catch {
				Write-Error " <!> Environment creation failed.`n[py -m venv $private:originalEnvPath]
				$PsItem.ScriptStackTrace`n >> Backup [.$envName] at [$private:backupPath] <<"
				Pick_Environment
			}
			Set-Location $private:originalEnvPath
			New-Item -ItemType directory $(Join-Path $private:originalEnvPath "projs") | Out-Null
			Activate_Environment -path $private:originalEnvPath
			try {
				pip install -r $(Join-Path $private:backupPath ".libs.txt")
			} catch {
				Write-Error " Couldn't install libraries from file [$private:backupPath/.libs.txt], run
				cat $private:backupPath/.libs.txt to find out the libraries.`n $PsItem.ScriptStackTrace`n"
			}
			Write-Host " > Backup Successful including installed libraries!!."
			Set-Location $envsPath
			Remove-Item -r $private:backupPath
			Pick_Environment

		}
		('^n$') {
			Pick_Environment
		}
		('^q$') {
			Quit
		} default {
			Write-Host "`n > invalid input [$private:refreshFlag]"
			Refresh_Environment -envsPath $envsPath -envName $envName
		}
	}
}

function script:Remove_Environment{
	param(
		[parameter(Mandatory)]
		[string]$envName,
		[parameter(Mandatory)]
		[string]$path
	)
	if ($envName -cne (Split-Path $path -Leaf)) {
		Write-Error "`n <!> Preventative Crash:
     [$envName] isn't found in [$path].
	 Continuing deletion would haved yielded unpredictable results, consider manual removal instead."
		Pick_Environment
	}
	[string]$private:delInput = Read-Host " > Are you sure you want to:
 > Delete [$envName] ----<in>---- [$path]??
   [y|n] >"
	$private:delInput = $private:delInput.ToLower()
	
	switch -Regex ($private:delInput){
		('^y$') {	
			Set-Location $global:defaultPath
			Write-Output " > Deleting ... "
			Remove-Item -r $path
			Write-Output " > Environment [$envName] was deleted successfully"
			Pick_Environment
		}
		('^n$') {
			Set-Location $global:defaultPath
			Pick_Environment
		}
		default {
			Write-Output "`n > Invalid input [$private:delInput]."
			Remove_Environment -path $newEnvPath -envName $envName
		}
	}
}

function script:List_Environments {
	param(
		[parameter(Mandatory)]
		[string]$path
	)
	$private:environmentList = [System.Collections.Generic.List[string]]::new()
	[int16]$private:itr = 0
	Write-Host "
 > Pick the corresponding idx for the Environment you want:`n
 /----------------------------\
  [Index] -----> [Environment Name]
  ----------------------------"
	foreach($env in $(Get-ChildItem $path -Name)) {

		Write-Host "   [$private:itr] --------> [$env]"
		$private:itr+=1
		$private:environmentList.Add($env)
		
	}
	Write-Host " \----------------------------/"

	return $private:environmentList
}

function script:Pick_Environment {
	
	$Local:environmentsList = List_Environments -path $script:defaultPath
	Write-Host ">> $($Local:environmentsList | Where-Object {$_ -match "test_env"})"
	[string]$private:envIndex = Read-Host "`n idx [q(uit)] => "
	[int16]$private:arraySize = $local:environmentsList.Count

	[bool]$private:invalidIndex = !(
		(($private:envIndex -match "^[0-9]+$") -and
			([int16]$private:envIndex -lt $private:arraySize)) -or
			($private:envIndex -match "^q$")
		)
	if ($invalidIndex) {
		Write-Output "`n > Invalid idx [$private:envIndex]!."
		Pick_Environment
	}

	if ($private:envIndex -match "^q$") {
		Quit
	}

	[string]$private:env = $local:environmentsList[[int16]$private:envIndex]
	[string]$private:pickFlag = Read-Host "`n > Selectd [$private:env]
 > Activate environment ------- [o]
 > Re-select ------------------ [n]
 > Remove environment --------- [d] 
 > Refresh environment -------- [r]
 > Quit ----------------------- [q]`n >"
	$private:pickFlag = $private:pickFlag.ToLower()
	
	$local:newEnvPath = Join-Path $script:defaultPath $private:env

	switch -Regex ($private:pickFlag) {
		('^q$') {
			Quit
		}
		('^d$') {
			Remove_Environment -path $local:newEnvPath -envName $private:env
		}
		('^o$|^\s$') {
			Write-Output " > Activating .... "
			Set-Location $local:newEnvPath
			Activate_Environment -path $local:newEnvPath
		}
		('^n$') {
			Pick_Environment
		}
		('^r$') {
			Refresh_Environment -enviromentsPath $script:defaultPath -envName $private:env
		}
		default {
			Write-Output " > Invalid input [$private:pickFlag]."
			Pick_Environment
		}
	}
}

Main
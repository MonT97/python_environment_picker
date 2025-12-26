[CmdLetBinding(DefaultParameterSetName = 'default')]
param(
	[Parameter(ParameterSetName ='default', Position=0)]
	[string]$envName,
	[parameter(ParameterSetName = 'config', Mandatory)]
	[switch]$config,
	[parameter(ParameterSetName = 'config')]
	[string]$path,
	[parameter(ParameterSetName = 'config')]
	[switch]$uninstall
	)

."$PSScriptRoot\config.ps1"    #? Any function has a [cfg_] prefex

function script:Main {
	Initiate_Variables
	[string]$private:greet = Parse_Greet -path $script:defaultPath
	Write-Output $private:greet
	if ($script:isEnvironmentProvided) {
		Pick_Environment -envName $script:envName
	}
	elseif ($script:isEnvironmentNew) {
		Create_New_Environment -envName $script:envName -newEnvPath $script:newEnvironmentPath 
	} else {
		Pick_Environment
	}
}

function script:Initiate_Variables {
	[string]$script:workingDirectory = $PWD.path
	[string]$script:configFileName = ".penv_config.json"
	[string]$script:parentDirectoryPath = Split-Path -Parent $MyInvocation.ScriptName
	[string]$local:configFilePath = Join-Path $script:parentDirectoryPath $script:configFileName
	[PSCustomObject]$local:config = $(Get-Content $local:configFilePath -Raw |ConvertFrom-Json)
	[string]$script:defaultPath = $local:config.default_path
	[string]$script:installationPath = $local:config.installation_path
	[string]$script:newEnvironmentPath = Join-Path $script:defaultPath $script:envName
	[bool]$script:isEnvironmentNew = (
		!(Test-Path $script:newEnvironmentPath) -and ([bool]$script:envName)
		)
	[bool]$script:isEnvironmentProvided = (
		(Test-Path $script:newEnvironmentPath) -and ([bool]$script:envName)
		)
	}
	
function script:Parse_Greet {
	param(
		[parameter(Mandatory)]
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
 > To change the specified path:
   penv -config -path [example/path]
 > To uninstall:
   penv -config -uninstall

|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|"
	return $greet
}

function script:Quit {
	Set-Location $script:workingDirectory
	Write-Output " > Quitting ...`n"
	Write-Output "|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n`n"
	exit
}

function script:Create_New_Environment {
	param(
		[parameter(Mandatory)]
		[string]$envName,
		[parameter(Mandatory)]
		[string]$newEnvPath,
		[bool]$isEnvNew
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
			if ($local:isEnvNew) {
				New-Item -ItemType directory $(Join-Path $newEnvPath "projs") | Out-Null
				Pick_Environment
			}
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
				Copy-Item -r -Path $private:originalEnvPath -Destination $private:backupPath 
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
	param(
		[string]$envName
	)
	$Local:environmentsList = List_Environments -path $script:defaultPath
	if (($script:isEnvironmentProvided) -or ($script:isEnvironmentNew)) {
		[string]$private:env = $($Local:environmentsList | Where-Object {$_ -match $local:envName})
	} else {
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
	}

	Handle_Selection -env $env
}

function script:Handle_Selection {
	param(
		[parameter(Mandatory)]
		[string]$env
	)
	[string]$private:pickFlag = Read-Host "`n > Selectd [$private:env]
 > Activate environment ------- [o]
 > Remove environment --------- [d] 
 > Refresh environment -------- [r]
 > Re-select ------------------ [n]
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
			[bool]$private:hasProjectsDir = Test-Path (Join-Path $local:newEnvPath "projs")
			if (!$private:hasProjectsDir) {
				New-Item -ItemType directory $(Join-Path $private:originalEnvPath "projs") | Out-Null
			}
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

switch ($PSCmdlet.ParameterSetName) {
	('default') {
		Main
	}
	('config') {
		Initiate_Variables
		if ([bool]$script:path) {
			Write-Host ">> $script:path"
			cfg_Configure -path $script:path -instPath $script:parentDirectoryPath -cfgFileName $script:configFileName
			break
		}
		if ([bool]$script:uninstall) { 
			Write-Warning " <!> uninstall the tool?!!"
			cfg_Uninstall -instPath $script:installationPath
			break
		}
		Write-Warning " <!> input invalid, use:`n   > penv -config -path`n   or`n   > penv -config -uninstall"
	}
}
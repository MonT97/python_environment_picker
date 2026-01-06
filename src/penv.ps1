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

."$PSScriptRoot\utils.ps1"    #? Any function with a [utl_] prefex
."$PSScriptRoot\config.ps1"    #? Any function with a [cfg_] prefex

function script:Main {
	[string]$private:greet = Parse_Greet -path $script:defaultPath
	Write-Output $private:greet
	if ($script:isEnvironmentProvided) {
		Pick_Environment -envName $script:envName
	}
	elseif ($script:isEnvironmentNew) {
		Create_New_Environment -envName $script:envName -newEnvPath $script:newEnvironmentPath  -isEnvNew $script:isEnvironmentNew
	} else {
		Pick_Environment
	}
}

function script:Initiate_Variables {
	[string]$script:activeDirectory = $PWD.path
	[string]$script:configFileName = ".penv_config.json"
	[string]$script:parentDirectoryPath = Split-Path -Parent $MyInvocation.ScriptName
	[string]$local:configFilePath = Join-Path $script:parentDirectoryPath $script:configFileName
	[PSCustomObject]$local:config = $(Get-Content $local:configFilePath -Raw |ConvertFrom-Json)
	[string]$script:defaultPath = $local:config.default_environments_path
	[string]$script:installationPath = $local:config.installation_path
	[string]$script:newEnvironmentPath = Join-Path $script:defaultPath $script:envName
	[bool]$script:isEnvironmentNew = (
		!(Test-Path $script:newEnvironmentPath) -and ([bool]$script:envName)
		)
	[bool]$script:isEnvironmentProvided = (
		(Test-Path $script:newEnvironmentPath) -and ([bool]$script:envName)
		)
	function script:Validata_Initial_Variables {
		if (!(Test-Path $script:defaultPath)) {
			Write-Host " <!> The specified path doesn't exist, provide another one"
			utl_Quit -path $script:activeDirectory
		}
	}
	Validata_Initial_Variables
}
	
function script:Parse_Greet {
	param(
		[parameter(Mandatory)]
		[string]$path
	)
	[string]$private:greet =  "

/==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==\
|                    Python Environment Picker                     |
\==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==/

 > The specified path is:
   [$path]
 > To change the specified path:
   penv -config -path [example/path]
 > To create a new environment:
   penv [env_name]
 > To uninstall the tool:
   penv -config -uninstall
   
|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n"
	return $greet
}

function script:Create_New_Environment {
	param(
		[parameter(Mandatory)]
		[string]$envName,
		[parameter(Mandatory)]
		[string]$newEnvPath,
		[bool]$isEnvNew
	)
	do {
		$private:pickFlag = (Read-Host " > Create new [$envName] at [$newEnvPath]?
 [y|q(uit)]`n >").ToLower()
		if ($private:pickFlag -notmatch '^y$|^$|^q$') {
			Write-Output " > Invalid iput[$private:pickFlag]`n >"
		}
	} while ($private:pickFlag -notmatch '^y$|^$|^q$')
	
	switch -Regex ($private:pickFlag) {
		('^y$|^$') {
			Write-Output " > Creating environment [$envName] ... `n"
			try {
				py -m venv $newEnvPath
				utl_Throw_Error
			} catch {
				Write-Error " <!> Environment creation failed.`n[py -m venv `$newEnvPath]"
				utl_Quit -path $script:activeDirectory
			}
			[bool]$private:envCreated = $(test-path $newEnvPath)
			Write-Output " > Environment [$envName] created [$envCreated]`n"
			if ($local:isEnvNew) {
				New-Item -ItemType directory $(Join-Path $newEnvPath "projs") | Out-Null
				Pick_Environment -envName $envName
			}
		}
		('^q$') {
			utl_Quit -path $script:activeDirectory
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
	do {
		[string]$private:refreshFlag = (
			Read-Host " > Refresh [$envName] at [$envsPath]?`n [y|n|q(uit)] >"
			).ToLower()
		if ($private:refreshFlag -notmatch '^y$|^$|^n$|^q$') {
			Write-Host "`n > Invalid input [$private:refreshFlag]"
		}
	} while ($private:refreshFlag -notmatch '^y$|^$|^n$|^q$')

	switch -Regex ($private:refreshFlag) {
		('^n$') {
			Pick_Environment
		}
		('^q$') {
			utl_Quit -path $script:activeDirectory
		}
		('^y$|^$') {
			[string]$private:originalEnvPath = Join-Path $envsPath $envName
			[string]$private:backupPath = Join-Path $envsPath ".$envName"

			Write-Host " > Creating backup ..."
			try {
				Copy-Item -r -Path $private:originalEnvPath -Destination $private:backupPath 
			} catch {
				Write-Error " <!> Something went wrong, couldn't create the backup!"
				Remove-Item -r $private:backupPath
				Refresh_Environment -envsPath $envsPath -envName $envName
			}
			Activate_Environment -path $private:originalEnvPath
			Set-Location $envsPath
			try {
				pip freeze > Join-Path $private:backupPath ".libs.txt"
				utl_Throw_Error
			}
			catch {
				Write-Error " <!> Couldn't create pip [requirement.txt] file at [$private:backupPath/.libs.txt]!.`n  !> Tried to backup .[$envName] at [$private:backupPath]`n  !> Consider manual backup"
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
				utl_Throw_Error
			} catch {
				Write-Error " <!> Environment creation failed.`n[py -m venv $private:originalEnvPath]  !> Tried to backup .[$envName] at [$private:backupPath]"
				Pick_Environment
			}
			Set-Location $private:originalEnvPath
			New-Item -ItemType directory $(Join-Path $private:originalEnvPath "projs") | Out-Null
			Activate_Environment -path $private:originalEnvPath
			try {
				pip install -r $(Join-Path $private:backupPath ".libs.txt")
				utl_Throw_Error
			} catch {
				Write-Error " <!> Couldn't install libraries from file [$private:backupPath/.libs.txt],  !> Run`n     cat $private:backupPath/.libs.txt to find out the libraries"
			}
			Write-Host " > Backup ----> successful`n > Installed libraries ----> successful"
			Set-Location $envsPath
			Remove-Item -r $private:backupPath
			Pick_Environment
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
		Write-Error "`n <!> Preventative Crash: [$envName] isn't found in [$path] continuing deletion would have yielded unpredictable results; consider manual removal instead"
		Pick_Environment
	}
	do {
		[string]$private:delInput = (Read-Host " > Are you sure you want to:
 > Delete [$envName] ----<in>---- [$path]?`n  [y|n] >").ToLower()
		if ($private:delInput -notmatch '^y$|$n^') {
			Write-Output "`n > Invalid input [$private:delInput]"
		}
	} while ($private:delInput -notmatch '^y$|^n$')
	switch -Regex ($private:delInput) {
		('^y$') {
			Set-Location $script:defaultPath
			Write-Output " > Deleting ... "
			Remove-Item -r $path
			Write-Output " > Environment [$envName] was deleted successfully"
			Pick_Environment
		}
		('^n$') {
			Set-Location $script:defaultPath
			Pick_Environment
		}
	}
}

function script:List_Environments {
	param(
		[parameter(Mandatory)]
		[string]$path
	)
	$private:environmentList = [System.Collections.Generic.List[string]]::new()
	$private:environments = $(Get-ChildItem $path -Name)
	if (![bool]$private:environments.Length){
		Write-Host " > The provided path is empty, change the path or create a new environment"
		utl_Quit -path $script:activeDirectory
	}
	[int16]$private:itr = 0
	Write-Host "
 > Pick the corresponding index for the Environment you want:`n
 /---------------------------------\
  [Index] -----> [Environment Name]
  ---------------------------------"
	foreach($env in $private:environments) {

		Write-Host "    [$private:itr] --------> [$env]"
		$private:itr+=1
		$private:environmentList.Add($env)
		
	}
	Write-Host " \---------------------------------/"

	return $private:environmentList
}

function script:Pick_Environment {
	param(
		[string]$envName
	)
	$Local:environmentsList = List_Environments -path $script:defaultPath
	if ([bool]$envName) {
		[string]$private:env = $($Local:environmentsList | Where-Object {$_ -match $local:envName})
	} else {
		[string]$private:envIndex = Read-Host "`n [idx|q(uit)] => "
		[int16]$private:arraySize = $local:environmentsList.Count
	
		[bool]$private:invalidIndex = !(
			(($private:envIndex -match '^[0-9]+$') -and
				([int16]$private:envIndex -lt $private:arraySize)) -or
				($private:envIndex -match '^q$')
			)
		if ($invalidIndex) {
			Write-Output "`n > Invalid idx [$private:envIndex]!"
			Pick_Environment -envName $envName
		}
		if ($private:envIndex -match '^q$') {
			utl_Quit -path $script:activeDirectory
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
	do {
		$local:envPath = Join-Path $script:defaultPath $private:env
		[string]$private:pickFlag = (Read-Host "`n > Selected [$private:env]
 > Activate environment ------- [o]
 > Remove environment --------- [d] 
 > Refresh environment -------- [r]
 > Re-select ------------------ [n]
 > Quit ----------------------- [q]`n >").ToLower()
		if ($private:pickFlag -notmatch '^q$|^d$|^o$|^n$|^r$|^\s$') {
			Write-Output " > Invalid input [$private:pickFlag]"
		}
	} while ($private:pickFlag -notmatch '^q$|^d$|^o$|^n$|^r$|^\s$')
	switch -Regex ($private:pickFlag) {
		('^q$') {
			utl_Quit -path $script:activeDirectory
		}
		('^d$') {
			Remove_Environment -path $local:envPath -envName $private:env
		}
		('^o$|^\s$') {
			Write-Output " > Activating .... "
			Set-Location $local:envPath
			[bool]$private:hasProjectsDir = Test-Path (Join-Path $local:envPath "projs")
			if (!$private:hasProjectsDir) {
				New-Item -ItemType directory $(Join-Path $private:envPath "projs") | Out-Null
			}
			Activate_Environment -path $local:envPath
		}
		('^n$') {
			Pick_Environment
		}
		('^r$') {
			Refresh_Environment -envsPath $script:defaultPath -envName $private:env
		}
	}
}

function script:Handle_Main_Input{
	param(
		[string]$mainInput
	)
	Initiate_Variables
	do {
		Write-Warning " <!> Input invalid, use:`n     penv -config -path`n   or`n     penv -config -uninstall"
	} while ($mainInput -cnotin ('default', 'config'))
	switch ($mainInput) {
		('default') {
			Main
		}
		('config') {
			if ([bool]$script:path) {
				cfg_Configure -path $script:path -instPath $script:parentDirectoryPath -cfgFileName $script:configFileName
				break
			}
			if ([bool]$script:uninstall) {
				cfg_Uninstall -instPath $script:installationPath
				break
			}
		}
	}
}

Handle_Main_Input -mainInput $PSCmdlet.ParameterSetName
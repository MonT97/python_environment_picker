."$PSScriptRoot\utils.ps1"    #? Any function with a [utl_] prefex
function script:Main {
    Initiate_Variables
    Write-Output "
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

"
    Validate_Installation -path $script:installationPath
}

function script:Initiate_Variables {
    [string]$script:toolDirectory = "src"
    [string]$script:installationDirectory = "penvpickr"
    [string]$script:mainScriptName = "penv.ps1"
    [string]$script:backupFileName = ".PATH_back_up.txt"
    [string]$script:activeDirectory = $PWD.Path
    [string]$script:toolPath = Join-Path $script:activeDirectory $script:toolDirectory
    [string]$script:backUpFilePath = Join-Path $script:activeDirectory $script:backupFileName
    [string]$script:installationPath = Join-Path $env:LOCALAPPDATA $script:installationDirectory
    [string]$script:mainScriptPath = Join-Path $script:installationPath $script:mainScriptName
}

function script:Validate_Installation {
    param(
        [parameter(Mandatory)]
        [string]$path
    )
    [bool]$private:isInstalled = Test-Path $path
    do {
        [string]$private:installFlag = (Read-Host " > Install the penv tool?`n [y|n] > ").ToLower()
        $private:inpFlag = $private:installFlag -notmatch '^y$|^n$'
        if ($private:inpFlag) {
            Write-Host " > Invalid input`n"
        }
    } while ($private:inpFlag)
    switch -Regex ($private:installFlag) {
        ('^y$') {
            Install_Tool -instPath $script:installationPath -path $path -reinstalling $private:isInstalled
        }
        ('^n$') {
            utl_Quit -path $script:activeDirectory
        }
    }
}

function script:Install_Tool {
    param (
        [parameter(Mandatory)]
        [string]$instPath,
        [parameter(Mandatory)]
        [string]$path,
        [bool]$reinstalling
    )
    Write-Host "`n > Installing tool in [$path] ..."
    New-Item -ItemType directory $instPath -Force | Out-Null
    Get-ChildItem $script:toolPath -Filter *.ps1 | Copy-Item -Destination $instPath
    Create_Config
    $local:addedToPATH = {param($p) [System.Environment]::GetEnvironmentVariable('path', 'user') -like "*$instPath*"}
    if (!(&$local:addedToPATH)) {
        Add_To_PATH -instPath $instPath -backUpPath $script:backUpFilePath
    }
    Write-Host " > Tool installed ---> [$(Test-Path $instPath)].
 > Added to PATH ----> [$(&$local:addedToPATH)]"
    Get-ChildItem $instPath
    Write-Host "`n > Type [penv] in any terminal session to run the tool"
    Write-Output "`n|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|"
}

function script:Add_To_PATH {
    param(
        [parameter(Mandatory)]
        [string]$instPath,
        [parameter(Mandatory)]
        [string]$backUpPath
    )
    $private:oldPATH = [System.Environment]::GetEnvironmentVariable('path', 'user')
    $private:newPATH = $private:oldPATH + ";$instPath"
    New-Item -ItemType file $backUpPath -Force | Out-Null
    Write-Output $private:oldPATH > $backUpPath
    [System.Environment]::SetEnvironmentVariable('path', $private:newPATH, 'user')
}

function script:Create_Config {
    [string]$local:configFileName = ".penv_config.json"
	[string]$local:configFilePath = $(Join-Path $script:installationPath $local:configFileName)
	Look_For_Config_File -path $local:configFilePath
}

function script:Look_For_Config_File {
	param(
		[Parameter(Mandatory)]
		[string]$path
	)
	[bool]$private:configFileNotFound = !(Test-Path $path)
	if ($private:configFileNotFound) {
		#! The used shouldn't know about the internal workings, so no "config file not found" massaga
		Write-Host "`n > No default envronments path is provided"
		$private:environmentPath = Read-Host " !> Provide The evnironments path:`n >"
		if (Test-Path $private:environmentPath) {
			Create_Config_File -envsPath $private:environmentPath -path $path
            return
		}
		Write-Host " <!> Invalid path!"
		Look_For_Config_File -path $path
	}
}

function script:Create_Config_File {
	param(
		[parameter(Mandatory)]
		[string]$envsPath,
		[parameter(Mandatory)]
		[string]$path
		)
    New-Item -ItemType File $path | Out-Null
    $local:config = ConvertTo-Json @{
        creation_date = $(Get-Date -Format yy/MM/dd--[HH:mm])
        self_path = $path
        default_environments_path = $envsPath
        old_default_environments_path = $envsPath
        installation_path = $script:installationPath
    }
    $local:config > $path
    $local:configFromFile = ConvertFrom-Json $local:config
    Write-Host " > Created config file at [$path]"
    Write-Host " > New default path is [$($local:configFromFile.default_environments_path)]`n"
}

Main
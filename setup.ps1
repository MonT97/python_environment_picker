function script:Main {
    Initiate_Variables
    Write-Output "`n|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n"
    Validate_Installation -path $script:installationPath
}

function script:Initiate_Variables {
    [string]$script:toolDirectory = "tool"
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
    if ($private:isInstalled) {
        Write-Host " > Tool is already installed!!.`n > path [$path]."
        [string]$private:installFlag = Read-Host " > You want to re-install the penv tool? [y|n]`n > "
    } else {
        [string]$private:installFlag = Read-Host " > You want to install the penv tool? [y|n]`n > "
    }
    switch -Regex ($private:installFlag.ToLower()) {
        ('^y$') {
            Install_Tool -path $path -reinstalling $private:isInstalled
        }
        ('^n$') {
            Quit
        }
        Default {
            Write-Host " > Invalid input, please enter [y] or [n]."
            Validate_Installation -path $path
        }
    }
}

function script:Install_Tool {
    param (
        [parameter(Mandatory)]
        [string]$path,
        [bool]$reinstalling
    )
    Write-Host " > installing tool in [$path] ..."
    New-Item -ItemType directory $script:installationPath -Force | Out-Null
    Get-ChildItem $script:toolPath -Filter *.ps1 | Copy-Item -Destination $script:installationPath
    #? No need, it well only be used here!
    [bool]$local:addedToPath = (
        [System.Environment]::GetEnvironmentVariable('path', 'user') -like "*$script:installationPath*")
    if (!($local:addedToPath) -and !($reinstalling)) {
        Add2PATH -instPath $script:installationPath -bUpPath $script:backUpFilePath
    }
    Write-Host " > Tool installed ---> [$(Test-Path $script:installationPath)].
    > Added to PATH --> [$local:addedToPath]"
    Get-ChildItem $script:installationPath
    Write-Output "`n|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n`n"
}


function script:Add2PATH {
    param(
        [parameter(Mandatory)]
        [string]$instPath,
        [parameter(Mandatory)]
        [string]$bUpPath
    )
    $private:oldPATH = [System.Environment]::GetEnvironmentVariable('path', 'user')
    $private:newPATH = $private:oldPATH + $instPath   
    New-Item -ItemType file $bUpPath -Force | Out-Null
    Write-Output $($private:oldPATH + $instPath) > $bUpPath
    [System.Environment]::SetEnvironmentVariable('path', $private:newPATH, 'user')
}

function script:Quit {
	Set-Location $script:activeDirectory
	Write-Output " > Quitting ...`n"
	Write-Output "|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n`n"
	exit
}

[string]$script:selfName = $MyInvocation.MyCommand
Main
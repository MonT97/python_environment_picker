function script:utl_Validate_Py_Installation {
    try {
        python -V 2>&1
        utl_Throw_Error
    } catch {
        Write-Error "`n <!> Python is not installed, rendering the tool useless for you, install python from [www.python.org].`n   > Remember to check the add to PATH box during the setup prcess"
        utl_Quit -path $PWD.path
    }
}

function script:utl_Throw_Error {
	if ($LASTEXITCODE -ne 0) {
		throw "`n$($LASTEXITCODE)`n"
	}
}

function script:utl_Quit {
    param(
        [string]$path
    )
	Set-Location $path
	Write-Output "`n > Quitting ...`n"
	Write-Output "|==--==--==--==--==--==--==--==--<>--==--==--==--==--==--==--==--==|`n`n"
	exit
}
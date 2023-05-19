function Get-GcsFile {
	param(
		[Parameter()][string]$GcsObject,
		[Parameter()][string]$TargetFile,
		[Parameter()][switch]$UseS5Cmd
	)

	$GcsFileExists = Invoke-GsUtil -Action CheckExists -GcsObjectPath $GcsObject
	if ( $GcsFileExists ) { # If the file was found
		Write-Substatus "Downloading $GcsObject from GCS."
		try {
			if ($UseS5Cmd) {
				Invoke-Gsutil -Action Download -GcsObjectPath "$GcsObject" -LocalObjectPath $TargetFile -UseS5Cmd # Download the object from GCP
			} else {
				Invoke-Gsutil -Action Download -GcsObjectPath "$GcsObject" -LocalObjectPath $TargetFile # Download the object from GCP
			}
			Write-Substatus "File download complete."
		} catch {
			Write-Status "Failed to download $GcsObject from GCS." $_
		}
	} else {
		Write-Status "File not found on GCS." -Type ERROR
	}
}
function Get-WebFile {
	param(
		[Parameter(Mandatory)][string]$SourceURI,
		[Parameter(Mandatory)][string]$TargetFile
	)

	Write-Substatus "Downloading $SourceURI"
	try {
		(New-Object System.Net.WebClient).DownloadFile($SourceURI, $TargetFile)
	} catch {
		Write-Status "Failed to download the file from $SourceURI" $_
	}
}

function Invoke-Gsutil {
	param(
		[Parameter()][ValidateSet("CheckExists","Upload","Download","Delete")][string]$Action,
		[Parameter()][string]$GcsObjectPath,
		[Parameter()][string]$LocalObjectPath,
		[Parameter()][switch]$OpportunisticDownload,
		[Parameter()][switch]$UseS5Cmd
	)

	if ($GcsObjectPath -notlike "gs://*") {
		$GcsObjectPath = "gs://$GcsObjectPath"
	}

	if ($GcsObjectPath -match "\s" -and ($GcsObjectPath -notlike "'*'") -or $GcsObjectPath -notlike "`"*`"") {
		$GcsObjectPath = "`"$GcsObjectPath`""
	}

	switch ($Action) {
		"CheckExists" {
			$process = Start-ExternalProcess -Executable "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd" -Arguments "-q stat $GcsObjectPath"
			if ($process.ExitCode) {
				return $false
			}
			break
		}
		"Upload" {
			# The parameter '-o GSUtil:parallel_composite_upload_threshold=150M' is SUPPOSED to increase performance, but on Windows it does not. If a bugfix is ever supplied for this, we should add this parameter back in.
			$process = Start-ExternalProcess -Executable "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd" -Arguments "cp `"$LocalObjectPath`" $GcsObjectPath"
			break
		}
		"Download" {
			if ($UseS5Cmd) {
				$GcsObjectPath = $GcsObjectPath.Replace("gs://","s3://")
	
				$process = Start-ExternalProcess -Executable $s5cmdExecutable -Arguments "--no-sign-request --endpoint-url https://storage.googleapis.com cp -c=1 -p=1000000 $GcsObjectPath `"$LocalObjectPath`""
			} else {
				$process = Start-ExternalProcess -Executable "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd" -Arguments "-o GSUtil:parallel_thread_count=1 -o GSUtil:sliced_object_download_max_components=8 cp $GcsObjectPath `"$LocalObjectPath`""
			}
			
			if ($OpportunisticDownload -and $process.ExitCode) { # If the function is called in opportunistic mode and the download fails (usually because the file doesn't exist), just return false without a fatal error
				return $false
			}
			break
		}
		"Delete" {
			$process = Start-ExternalProcess -Executable "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd" -Arguments "rm $GcsObjectPath"
			break
		}
	}

	if ($process.ExitCode) {
		Write-Status "gsutil exited with code $($process.ExitCode) and error message: $($process.Error)" -Level ERROR -Fatal
	} else {
		return $true
	}
}

function Set-Registry {
	param(
		[Parameter(Mandatory)][string]$KeyPath,
		[Parameter()][string]$PropertyName,
		[Parameter()]$PropertyValue,
		[Parameter()][hashtable]$PropertyHash,
		[Parameter()][switch]$Delete
	)

	if ($Delete) {
		if ($PropertyName) {
			Write-Substatus "Deleting registry property $KeyPath\$PropertyName"
			try {
				[void](Remove-ItemProperty -Path $KeyPath -Name $PropertyName -Force -ErrorAction Stop)
			} catch {
				Write-Status "Failed to delete registry property $KeyPath\$PropertyName" $_ -NonFatal
			}
		} else {
			Write-Substatus "Deleting registry key $KeyPath"
			try {
				[void](Remove-Item -Path $KeyPath -Force -ErrorAction Stop)
			} catch {
				Write-Status "Failed to delete registry key $KeyPath" $_ -NonFatal
			}
		}
		return
	}

	if ((Test-Path $KeyPath)) {
		Write-Status "Found registry key $KeyPath"
	} else {
		try {
			[void](New-Item -Path $KeyPath -Force -ErrorAction Stop)
			Write-Substatus "Created registry key $KeyPath"
		} catch {
			Write-Status "Failed to create registry key $KeyPath" $_
		}
	}
	
	if ($PropertyName -and ($null -ne $PropertyValue)) {
		Set-RegistryValue -KeyPath $KeyPath -PropertyName $PropertyName -PropertyValue $PropertyValue
	}

	if ($PropertyHash) {
		foreach ($property in $PropertyHash.Keys) {
			Set-RegistryValue -KeyPath $KeyPath -PropertyName $property -PropertyValue $PropertyHash[$property]
		}
	}
}

function Set-RegistryValue {
	param(
		[Parameter(Mandatory)][string]$KeyPath,
		[Parameter(Mandatory)][string]$PropertyName,
		[Parameter(Mandatory)]$PropertyValue
	)

	try {
		[void](Set-ItemProperty -Path $KeyPath -Name $PropertyName -Value $PropertyValue -Force -ErrorAction Stop)
		Write-Substatus "Set registry property $KeyPath\$PropertyName to $PropertyValue"
	} catch {
		Write-Status "Failed to set registry property $KeyPath\$PropertyName to $PropertyValue" $_
	}
}

function Start-ExternalProcess {
	param(
		[Parameter(Mandatory)][string]$Executable,
		[Parameter()][string[]]$Arguments,
		[Parameter()][switch]$RunElevated,
		[Parameter()][int[]]$SuccessExitCodes,
		[Parameter()][switch]$DoNotWait,
		[Parameter()][string]$WorkingDirectory
	)

	$procInfo = New-Object System.Diagnostics.ProcessStartInfo
	$procInfo.FileName = $Executable
	
	if ($RunElevated) {
		$procInfo.UseShellExecute = $true
		$procInfo.Verb = "Runas"
	} else {
		$procInfo.RedirectStandardError = $true
		$procInfo.RedirectStandardOutput = $true
		$procInfo.UseShellExecute = $false
	}

	if ($Arguments) {
		$procInfo.Arguments = $Arguments -join " "
	}

	if ($WorkingDirectory) {
		$procInfo.WorkingDirectory = $WorkingDirectory
	}

	try {
		Write-Status "Starting process $Executable $($Arguments -join " ")"
		$proc = New-Object System.Diagnostics.Process
		$proc.StartInfo = $procInfo
		[void]($proc.Start())
	} catch {
		Write-Status "Failed to start process $Executable" $_
	}

	if ($DoNotWait) {
		Write-Substatus "Not waiting for process to complete. Output and exit code will not be returned."
		return
	}

	$proc.WaitForExit()
	
	Write-Substatus "Process exit code: $($proc.ExitCode)"
	if ($RunElevated) {
		Write-Status "Elevated commands cannot show their stdout or stderr" -Type WARNING
	} else {
		$stdout = $proc.StandardOutput.ReadToEnd()
		$stderr = $proc.StandardError.ReadToEnd()
	}

	if ($SuccessExitCodes -and $proc.ExitCode -notin $SuccessExitCodes) {
		Write-Status "Exit code not in the list of success error codes: $($SuccessExitCodes -join ",")" -Type ERROR
	}

	return [pscustomobject]@{"ExitCode" = $proc.ExitCode; "Output" = $stdOut; "Error" = $stdErr}
}

function Write-Status {
	param(
		[Parameter()][string]$Message,
		[Parameter()]$Exception,
		[Parameter()][ValidateSet("INFO","WARNING","ERROR")][string]$Type = "INFO",
		[Parameter()][switch]$NonFatal
	)

	$Timestamp = [DateTime]::now.ToString("hh:mm:ss tt")

	if ($Exception) {
		$Type = "ERROR"
		# If there's also a message alongside the exception, write the message first and then replace it with the exception message to write the next line
		if ($Message) {
			Write-Host "$Timestamp`t$($Type.PadRight(7))`t$Message"
		}
		$Message = $Exception.Exception.Message
	}

	Write-Host "$Timestamp`t$($Type.PadRight(7))`t$Message"
	
	if (($Type -eq "ERROR" -or $Exception) -and -not $NonFatal) {
		Write-Host "The previous error was fatal. Exiting script"
		exit 1
	}
}

# A simple overload function to simplify writing substatuses to the Packer output. Errors and exceptions never get written as substatus, so we just need the message parameter
function Write-Substatus {
	param(
		[Parameter()][string]$Message
	)

	$Message = "- $Message"

	Write-Status -Message $Message
}

#### CONSTANTS ####
$ErrorActionPreference = 'Stop'
$s5cmdExecutable = "C:\Program Files\itopia\Utilities\s5cmd\s5cmd.exe"

#### PROCESS ####
Write-Status "Setting PowerShell to use TLS1.2 for better downloading support"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Export-ModuleMember -Function Set-Registry,Start-ExternalProcess,Write-Status,Write-Substatus,Get-WebFile,Get-GcsFile
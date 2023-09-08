# Download Packer plugins
& packer.exe init ".\images\win-2022-base\main.pkr.hcl"

# Update the administrator password in the Autounattend file
try {
	$secrets = ConvertFrom-Json -InputObject $(Get-Content -Path .\secret_vars.json -Raw)
} catch {
	Write-Error "Failed to read secret_vars.json in the root of this project. Please ensure this file exists and is configured "
	break
}

if (-not $secrets.administrator_password) {
	Write-Error "Failed to read 'administrator_password' from the secret_vars.json file. Please ensure this value is present."
	break
}

$unattend = Get-Content -Path .\files\floppy\autounattend.xml -Raw
$unattend.Replace("REPLACEME!",$secrets.administrator_password) | Out-File -FilePath.\files\floppy\autounattend.xml -Encoding utf8 -Force

# Packer build
& packer.exe build -force -var-file=".\images\win-2022-base\base.auto.pkrvars.hcl" -var-file=".\secret_vars.json" ".\images\win-2022-base\main.pkr.hcl"

# Revert password in autounattend.xml
$unattend.Replace($secrets.administrator_password,"REPLACEME!") | Out-File -FilePath.\files\floppy\autounattend.xml -Encoding utf8 -Force
# Set Windows KMS Server
# Description: This will set the KMS server for Windows
# OS: Windows 2022
# Notes: None

$ProductKey = "WX4NM-KYWYW-QJJR4-XV3QB-6VM33" # Generic KMS key
$KmsHost = $env:KMS

Import-Module -Name "C:\Temp\BuildFunctions.psm1"

# TODO: Switch to the WMI method to set/validate this more programmatically?
# Register with KMS
Set-Location -Path "$env:SystemRoot\System32"

Write-Status "Installing product key $ProductKey"
$process = Start-ExternalProcess -Executable "cscript.exe" -Arguments "$env:SystemRoot\System32\slmgr.vbs /ipk $productKey" -SuccessExitCodes 0
Write-Status "slmgr.vbs /skms exited with code: $($process.ExitCode)"
Write-Status "slmgr.vbs /skms StdOut: $($process.Output)"
Write-Status "slmgr.vbs /skms StdErr: $($process.Error)"

Write-Status "Setting KMS server to $KmsHost and activating Windows"
$process = Start-ExternalProcess -Executable "cscript.exe" -Arguments "$env:SystemRoot\System32\slmgr.vbs /skms $KmsHost" -SuccessExitCodes 0
Write-Status "slmgr.vbs /skms exited with code: $($process.ExitCode)"
Write-Status "slmgr.vbs /skms StdOut: $($process.Output)"
Write-Status "slmgr.vbs /skms StdErr: $($process.Error)"
$process = Start-ExternalProcess -Executable "cscript.exe" -Arguments "$env:SystemRoot\System32\slmgr.vbs /ato" -SuccessExitCodes 0
Write-Status "slmgr.vbs /ato exited with code: $($process.ExitCode)"
Write-Status "slmgr.vbs /ato StdOut: $($process.Output)"
Write-Status "slmgr.vbs /ato StdErr: $($process.Error)"
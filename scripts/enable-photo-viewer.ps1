# The Windows Photo Viewer is disabled in Windows Server by default. This script re-enables it

$PhotoViewerRegFile = "C:\Temp\enable-photo-viewer.reg"

Import-Module -Name "C:\Temp\BuildFunctions.psm1"

Write-Status "Enabling the Windows Photo Viewer"
$process = Start-ExternalProcess -Executable "regsvr32.exe" -Arguments "/s C:\Program Files (x86)\Windows Photo Viewer\PhotoViewer.dll"
Write-Substatus "Process exited with code $($process.ExitCode)"

Write-Status "Registering the file handler info"
$process = Start-ExternalProcess -Executable "reg.exe" -Arguments "IMPORT $PhotoViewerRegFile"
Write-Substatus "Process exited with code $($process.ExitCode)"

[void](Remove-Item -Path $PhotoViewerRegFile -Force)
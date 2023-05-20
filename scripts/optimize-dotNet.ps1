# Optimize .NET
# Description: This will "optimize" any .NET applications during the build phase so it will not happen during first boot when the user logs on.
# OS: Any Windows
# Notes: None

Import-Module -Name "C:\Temp\BuildFunctions.psm1"

Write-Status "Optimizing .NET (32-bit)..."
Start-ExternalProcess -Executable "C:\Windows\Microsoft.NET\Framework\v4.0.30319\ngen.exe" -Arguments "executequeueditems /silent" -RunElevated

Write-Status "Optimizing .NET (64-bit)..."
Start-ExternalProcess -Executable "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\ngen.exe" -Arguments "executequeueditems /silent" -RunElevated

Write-Status "Disabling NGEN Scheduled Tasks"
try {
	[void](Get-ScheduledTask -TaskPath "\Microsoft\Windows\.NET Framework\" | Disable-ScheduledTask)
} catch {
	Write-Status "Failed to disable .NET Framework Scheduled Tasks" $_
}

Write-Status "Removing NGEN from Active Setup"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{89B4C1CD-B018-4511-B0A1-5476DBF70820}" -PropertyName "StubPath" -Delete
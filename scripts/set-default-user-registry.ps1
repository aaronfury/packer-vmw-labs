# This script mounts and modifies the registry hive for the "default" user, which is copied whenever a new profile is created

Import-Module -Name "C:\Temp\BuildFunctions.psm1"

$DefaultUserRootHive = "HKLM:\DefaultUserEdit"

Write-Status "Mounting the default user registry hive"
Start-ExternalProcess -Executable "reg.exe" -Arguments 'LOAD HKLM\DefaultUserEdit "C:\Users\Default\NTUSER.DAT"'

# Secondary check
if (-not (Test-Path $DefaultUserRootHive)) {
	Write-Status "Failed to mount the default user profile. Image cannot be configured." -Type ERROR
}

# Disable Toast Notifications
Write-Status "Disabling toast notifications"
Set-Registry -KeyPath "$DefaultUserRootHive\Software\Policies\Microsoft\Windows\Explorer" -PropertyName "DisableNotificationCenter" -PropertyValue 1
Set-Registry -KeyPath "$DefaultUserRootHive\Software\Microsoft\Windows\CurrentVersion\PushNotifications" -PropertyName "ToastEnable" -PropertyValue 0

# Disable Server Manager (redundant method, Scheduled Task is disabled elsewhere)
Write-Status "Disabling Server Manager auto-launch at login"
Set-Registry -KeyPath "$DefaultUserRootHive\Software\Microsoft\ServerManager" -PropertyName "DoNotOpenServerManagerAtLogon" -PropertyValue 1

# Configure Internet Zones (OneDrive compatibility)
Write-Status "Setting the Internet Security Zone for OneDrive compatibility"
Set-Registry -KeyPath "$DefaultUserRootHive\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -PropertyName "1400" -PropertyValue 0

$Policies = @(
	@("Hide the clock", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HideClock", 1),
	@("Remove Windows security from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoNTSecurity", 1),
	@("Remove Documents from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoSMMyDocs", 1),
	@("Remove Pictures from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoSMMyPictures", 1),
	@("Remove User directory from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoUserFolderInStartMenu", 1),
	@("Remove Recent documents from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoRecentDocsMenu", 1),
	@("Remove search from Start Menu", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoSearchComputerLinkInStartMenu", 1),
	@("Disable notifications (1)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "TaskbarNoNotification", 1),
	@("Disable notifications (2)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoAutoTrayNotify", 1),
	@("Disable notifications (3)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoTrayItemsDisplay", 1),
	@("Disable notifications (4)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoDriveTypeAutorun", 95),
	@("Disable notifications (5)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "DisableNotificationCenter", 1),
	@("Disable notifications (6)", "Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications", "NoToastApplicationNotification", 1),
	@("Disable system tray items (1)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HideSCAVolume", 1),
	@("Disable system tray items (2)", "Software\Microsoft\Windows\CurrentVersion\Policies\Explorer", "HideSCANetwork", 1),
	@("Disable untrusted file warning","Software\Microsoft\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3", "1806", 0)
	@("Hide Task View button", "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowTaskViewButton", 0),
	@("Enable thumbnail icons in Explorer", "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "IconsOnly", 0),
	@("Disable search features (1)","Software\Microsoft\Windows\CurrentVersion\Search", "SearchboxTaskbarMode", 0),
	@("Disable search features (2)","Software\Microsoft\Windows\CurrentVersion\Search", "BingSearchEnabled", 0),
	@("Disable search features (3)","Software\Microsoft\Windows\CurrentVersion\Search", "AllowSearchToUseLocation", 0),
	@("Disable search features (4)","Software\Microsoft\Windows\CurrentVersion\Search", "CortanaConsent", 0),
	@("Disabling screen saver", "Software\Policies\Microsoft\Windows\Control Panel\Desktop", "ScreenSaveActive", 0),
	@("Set mouse wheel scroll rate","Control Panel\Desktop", "WheelScrollLines", 1),
	@("Disable SmartScreen for App Store","Software\Microsoft\Windows\CurrentVersion\AppHost", "EnableWebContentEvaluation", 0),
	@("Disabling Telemetry (1)","SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo", "Enabled", 0),
	@("Disabling Telemetry (2)","Control Panel\International\User Profile", "HttpAcceptLanguageOptout", 1),
	@("Disabling Telemetry (3)","SOFTWARE\Microsoft\Windows\CurrentVersion\DeviceAccess\Global\LooselyCoupled", "Value", "Deny"),
	@("Disabling Telemetry (4)","SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore", "HarvestContacts", 0),
	@("Disabling Telemetry (5)","SOFTWARE\Microsoft\Personalization\Settings", "AcceptedPrivacyPolicy", 0),
	@("Disabling Feature advertisement balloons","SOFTWARE\Policies\Microsoft\Windows\Explorer", "NoBalloonFeatureAdvertisements", 1),
	@("Disabling Startup App Toast Notifications","SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp", "Enabled", 0)
)

foreach ($policy in $Policies) {
	Write-Substatus $policy[0]
	Set-Registry -KeyPath "$DefaultUserRootHive\$($policy[1])" -PropertyName $policy[2] -PropertyValue $policy[3]
}

Write-Status "Running a garbage collection to close handles into the loaded registry hive"
[gc]::collect()

Start-Sleep -Seconds 5

Write-Status "Unmounting the default user registry hive"
Start-ExternalProcess -Executable "reg.exe" -Arguments 'UNLOAD HKLM\DefaultUserEdit'
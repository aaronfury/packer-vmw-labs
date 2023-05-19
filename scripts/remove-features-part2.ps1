Import-Module -Name ".\BuildFunctions.psm1"

Write-Status "Removing Windows Packages"
$PackagesToRemove = @(
	"WindowsMediaPlayer",
	"PowerShell.ISE",
	"WordPad",
	"MSPaint",
	"OpenSSH.Client",
	"InternetExplorer"
)
$Packages = Get-WindowsCapability -Online
foreach ( $package in $Packages ) {
	foreach ($packageToRemove in $PackagesToRemove) {
		if ($package.Name -like "*$packageToRemove*") {
			try{
				Write-Substatus "Removing $($package.Name)"
				[void]($package | Remove-WindowsCapability -Online)
			} catch {
				Write-Status "Unable to remove $($package.Name)" $_
			}
		}
	}
}

# Uninstall Microsoft Edge
$EdgeRootPath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\"
$EdgeVersionPaths = Get-ChildItem -Path $EdgeRootPath -Directory | Where-Object {$_.Name -match '^[0-9].*'}

Write-Status "Uninstalling Microsoft Edge"
foreach ($versionPath in $EdgeVersionPaths) {
	Write-Substatus "Uninstalling version $($versionPath.Name)"
	$InstallerPath = $versionPath.FullName + "\Installer"
	Start-ExternalProcess -Executable "$InstallerPath\setup.exe" -Arguments "-uninstall -system-level -verbose-logging -force-uninstall" -SuccessExitCodes 0,19
}

# Uninstall OneDrive
if (Test-Path -Path $env:SystemRoot\SysWOW64\OneDriveSetup.exe -PathType Leaf) {
	Write-Status "Uninstalling OneDrive"
	Start-ExternalProcess -Executable "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -Arguments "/uninstall"
}


Write-Status "Disabling Defender SmartScreen"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -PropertyName "EnableSmartScreen" -PropertyValue 0

Write-Status "Disabling the Windows Firewall"
try {
	[void](Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private)
} catch {
	Write-Status "Failed to set the network connection to the 'Private' profile" $_
}

try {
	[void](Get-NetFirewallProfile | Set-NetFirewallProfile -Enabled False)
} catch {
	Write-Status "Failed to disable the firewall profiles" $_
}

Write-Status "Turning off the Network Location Wizard"
Set-Registry -KeyPath "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"

# Turn off Internet Explorer Enhanced Security
Write-Status "Disabling Internet Explorer Enhanced Security"
@(
	"HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}", # Admin key
	"HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" # User key
) | ForEach-Object {
	Set-Registry -KeyPath $_ -PropertyName "IsInstalled" -PropertyValue 0
}

# Turn off Untrusted File Warnings
Write-Status "Disabling Untrusted file warnings (needed for some silent installs)"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Security" -PropertyName "DisableSecuritySettingsCheck" -PropertyValue 1
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -PropertyName "1806" -PropertyValue 0
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -PropertyName "1806" -PropertyValue 0
Set-Registry -KeyPath "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" -PropertyName "1806" -PropertyValue 0

# Remove Windows Security Notifications from startup
Write-Status "Disabling autorun of the Windows Security App"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -PropertyName "SecurityHealth" -Delete

# Remove Windows Security Notifications from startup
Write-Status "Disabling notifications from the Security Center (Defender) app"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" -PropertyName "DisableNotifications" -PropertyValue 1

# Remove Windows Update notifications
Write-Status "Disabling Windows Update toast notifications"
try {
	[void](Get-ScheduledTask -TaskPath "\Microsoft\Windows\UpdateOrchestrator\" | Where-Object {$_.Actions.Execute -like "*MusNotification*"} | Unregister-ScheduledTask -Confirm:$False)
} catch {
	Write-Status "Failed to disable the Windows Update toast notiication task" $_
}

# Disable Windows Ink Workspace
Write-Status "Disabling Windows Ink Workspace"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace" -PropertyName "AllowWindowsInkWorkspace" -PropertyValue 0

# Disable pinned items in Start Menu
Write-Status "Disabling pinned items in Start Menu"
$PropertyHash = @{
	"AllowPinnedFolderDocuments" = 0;
	"AllowPinnedFolderDocuments_ProviderSet" = 1;
	"AllowPinnedFolderDownloads" = 0;
	"AllowPinnedFolderDownloads_ProviderSet" = 1;
	"AllowPinnedFolderFileExplorer" = 0;
	"AllowPinnedFolderFileExplorer_ProviderSet" = 1;
	"AllowPinnedFolderMusic" = 0;
	"AllowPinnedFolderMusic_ProviderSet" = 1;
	"AllowPinnedFolderNetwork" = 0;
	"AllowPinnedFolderNetwork_ProviderSet" = 1;
	"AllowPinnedFolderPersonalFolder" = 0;
	"AllowPinnedFolderPersonalFolder_ProviderSet" = 1;
	"AllowPinnedFolderPictures" = 0;
	"AllowPinnedFolderPictures_ProviderSet" = 1;
	"AllowPinnedFolderSettings" = 0;
	"AllowPinnedFolderSettings_ProviderSet" = 1;
	"AllowPinnedFolderVideos" = 0;
	"AllowPinnedFolderVideos_ProviderSet" = 1;
}
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" -PropertyHash $PropertyHash

Write-Substatus "Disabling Recycle Bin on the desktop"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{645FF040-5081-101B-9F08-00AA002F954E}" -Delete

# Disable Shutdown Event Tracker
Write-Status "Disabling the Shutdown Event Tracker"
$PropertyHash = @{
	"ShutdownReasonOn" = 0;
	"ShutdownReasonUI" = 0;
}
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Reliability" -PropertyHash $PropertyHash

# Disable Server Manager
Write-Status "Disabling the Server Manager login scheduled task"
try {
	[void](Get-ScheduledTask -TaskName "ServerManager" | Disable-ScheduledTask)
} catch {
	Write-Status "Failed to disable the scheduled task" $_
}

# Remove Lock screen timeout
Write-Status "Disabling the lockscreen"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" -PropertyName "NoLockScreen" -PropertyValue 1
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -PropertyName "InactivityTimeoutSecs" -PropertyValue 0

Write-Status "Disabling the screen saver and lock after resume"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" -PropertyName "ScreenSaverIsSecure" -PropertyValue 0
Set-Registry -KeyPath "REGISTRY::HKEY_USERS\.DEFAULT\Control Panel\Desktop" -PropertyName "ScreenSaveActive" -PropertyValue 0

Write-Status "Disabling the lockscreen a third way"
Start-ExternalProcess -Executable "powercfg.exe" -Arguments "/SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"
Start-ExternalProcess -Executable "powercfg.exe" -Arguments "/SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 0"

# Remove Windows Security shortcut from Start Menu
Write-Status "Removing Windows Security from Start Menu"
Start-ExternalProcess -Executable "reg.exe" -Arguments 'DELETE "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\InboxApplications\Microsoft.Windows.SecHealthUI_10.0.20348.859_neutral__cw5n1h2txyewy" /f'

# Disable Telemetry
Write-Status "Disabling telemetry collection and reporting"
@(
	@("HKLM:\Software\Policies\Microsoft\Windows\TabletPC", "PreventHandwritingDataSharing", 1),
	@("HKLM:\Software\Policies\Microsoft\Windows\HandwritingErrorReports", "PreventHandwritingErrorReports", 1),
	@("HKLM:\Software\Policies\Microsoft\Messenger\Client", "CEIP", 2),
	@("HKLM:\Software\Policies\Microsoft\SQMClient\Windows", "CEIPEnable", 0),
	@("HKLM:\Software\Policies\Microsoft\PCHealth\ErrorReporting", "DoReport", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice", "AllowFindMyDevice", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting", "DontSendAdditionalData", 1),
	@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "DisplayLastLogonInfo", 0),
	@("HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice", "LocationSyncEnabled", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting", "AutoApproveOSDumps", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo", "DisabledByGroupPolicy", 1),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat", "DisableInventory", 1),
	@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System", "DisableAutomaticRestartSignOn", 1), # TODO: Verify this one?
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE", "DisablePrivacyExperience", 1),
	@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection", "MicrosoftEdgeDataOptIn", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization", "RestrictImplicitTextCollection", 1),
	@("HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization", "RestrictImplicitInkCollection", 1),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection", "LimitEnhancedDiagnosticDataWindowsAnalytics", 0),
	@("HKLM:\Software\Policies\Microsoft\Windows\DataCollection", "DoNotShowFeedbackNotifications", 1),
	@("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput", "AllowLinguisticDataCollection", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting", "AutoApproveOSDumps", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting", "Disabled", 1),
	@("HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\BooksLibrary", "EnableExtendedBooksTelemetry", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat", "AITEnable", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection", "AllowTelemetry", 0)
) | ForEach-Object {
	Set-Registry -KeyPath $_[0] -PropertyName $_[1] -PropertyValue $_[2]
}

# Windows Autologgers provide trace abilities during kernel- and user-mode startup processes. They are unnecessary in ephemeral VM environments
Write-Status "Disabling Windows Auto-loggers"
@(
	@("Cloud Experience Host OOBE Autologger", "CloudExperienceHostOOBE\*"),
	@("DiagLog Autologger", "DiagLog\*"),
	@("NTFS Autologger", "NtfsLog\*"),
	@("Tile Store Autologger", "TileStore\*"),
	@("UBPM Autologger", "UBPM\*"),
	@("WDIContextLog Autologger", "WdiContextLog\*"),
	@("WiFi Driver IHV Session Autologger", "WiFiDriverIHVSession\*")
) | ForEach-Object {
	Set-Registry -KeyPath "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$($_[1])" -PropertyName "Enabled" -PropertyValue 0
}

Write-Status "Disabling Found New Hardware notifications"
Set-Registry -KeyPath "HKLM:\Software\Policies\Microsoft\Windows\DeviceInstall\Settings" -PropertyName "DisableBalloonTips" -PropertyValue 1

Write-Status "Disabling Microsoft Peer-to-Peer"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Peernet" -PropertyName "Disabled" -PropertyValue 1

Write-Status "Disabling unnecessary Windows Services"
@(
	@("Connected Devices Platform Service", "CDPSvc"),
	@("Connected Devices Platform User Service", "CDPUserSvc"),
	@("Windows Connection Manager", "Wcmsvc"),
	@("SysMain (Superfetch)", "Sysmain"),
	@("Distributed Link Tracking Client", "TrkWks"),
	@("Diagnostic Policy Service", "DPS"),
	@("Resouce Monitor", "RmSvc")
) | ForEach-Object {
	Write-Substatus "$($_[0])"
	try {
		[void](Set-Service -Name $_[1] -StartupType Disabled)
	} catch {
		Write-Status "Failed to disable the service" $_
	}
}

Write-Status "Disabling unnecessary network services"
@(
	@("Network Isolation automatic subnet discovery", "HKLM:\SOFTWARE\Policies\Microsoft\Windows\NetworkIsolation", "DSubnetsAuthoritive", 1),
	@("CIFS Notifications", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer", "NoRemoteRecursiveEvents",	1),
	@("IPv6", "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters", "DisabledComponents", 255),
	@("Network category changes","HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\EveryNetwork", "CategoryReadOnly", 1),
	@("KMS Client AVS Validation", "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform", "NoGenTicket", 1)
) | ForEach-Object {
	Write-Substatus "$($_[0])"
	Set-Registry -KeyPath $_[1] -PropertyName $_[2] -PropertyValue $_[3]
}

Write-Status "Disabling unnecessary Scheduled Tasks"
$ExcludedTaskNames = @("SyspartRepair")
@(
	"\Microsoft\Windows\Application Experience\",
	"\Microsoft\Windows\Customer Experience Improvement Program\",
	"\Microsoft\Windows\International\",
	"\Microsoft\Windows\Location\",
	"\Microsoft\Windows\SpacePort\",
	"\Microsoft\Windows\Windows Filtering Platform\",
	"\Microsoft\Windows\Windows Error Reporting\",
	"\Microsoft\Windows\WwanSvc\"
) | ForEach-Object {
	try {
		Write-Substatus $_
		[void](Get-ScheduledTask -TaskPath $_ | Where-Object { $_.TaskName -notin $ExcludedTaskNames } | Disable-ScheduledTask -ErrorAction Stop)
	} catch {
		Write-Status "Failed to disable these tasks" $_ -NonFatal
	}
}

@(
	@("Microsoft\Windows\StateRepository\", "MaintenanceTasks"),
	@("Microsoft\Windows\WOF\", "WIM-Hash-Management"),
	@("Microsoft\Windows\WOF\", "WIM-Hash-Validation"),
	@("Microsoft\Windows\Data Integrity Scan\", "Data Integrity Scan"),
	@("Microsoft\Windows\Data Integrity Scan\", "Data Integrity Check And Scan"),
	@("Microsoft\Windows\Management\Provisioning\", "Logon"),
	@("Microsoft\Windows\Windows Media Sharing\", "UpdateLibrary"),
	@("Microsoft\Windows\ApplicationData\", "appuriverifierdaily"),
	@("Microsoft\Windows\Bluetooth\", "UninstallDeviceTask"),
	@("Microsoft\Windows\Flighting\OneSettings\", "RefreshCache"),
	@("Microsoft\Windows\International\", "Synchronize Language Settings"),
	@("Microsoft\Windows\Registry\", "RegIdleBackup"),
	@("Microsoft\Windows\Servicing\", "StartComponentCleanup"),
	@("Microsoft\Windows\Shell\", "FamilySafetyMonitor"),
	@("Microsoft\Windows\Shell\", "FamilySafetyRefreshTask"),
	@("Microsoft\Windows\Shell\", "IndexerAutomaticMaintenance"),
	@("Microsoft\Windows\Maintenance\", "WinSAT"),
	@("Microsoft\Windows\SystemRestore\", "SR"),
	@("Microsoft\Windows\MemoryDiagnostic\", "ProcessMemoryDiagnosticEvents"),
	@("Microsoft\Windows\MemoryDiagnostic\", "RunFullMemoryDiagnostic"),
	@("Microsoft\Windows\Power Efficiency Diagnostics\", "AnalyzeSystem"),
	@("Microsoft\Windows\RecoveryEnvironment\", "VerifyWinRE"),
	@("Microsoft\Windows\ApplicationData\", "DsSvcCleanup"),
	@("Microsoft\Windows\Diagnosis\", "RecommendedTroubleshootingScanner"),
	@("Microsoft\Windows\Diagnosis\", "Scheduled"),
	@("Microsoft\Windows\Flighting\", "FeatureConfig\ReconcileFeatures"),
	@("Microsoft\Windows\DiskDiagnostic\", "Microsoft-Windows-DiskDiagnosticDataCollector"),
	@("Microsoft\Windows\Sysmain\", "ResPriStaticDbSync"),
	@("Microsoft\Windows\PI\", "Sqm-Tasks")
) | ForEach-Object {
	[void](Disable-ScheduledTask -TaskPath $_[0] -TaskName $_[1] -ErrorAction SilentlyContinue)
}


Write-Status "Configuring Power Plan settings"
@(
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\309dce9b-bef4-4119-9921-a851fb12f0f4", "ACSettingIndex", 0),
	@("HKLM:\Software\Policies\Microsoft\Power\PowerSettings", "ActivePowerScheme", "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA", "ACSettingIndex", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E", "ACSettingIndex", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\6738E2C4-E8A5-4A42-B16A-E040E769756E", "ACSettingIndex", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\94ac6d29-73ce-41a6-809f-6363ba21b47e", "ACSettingIndex", 0),
	@("HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\9D7815A6-7EE4-497E-8888-515A05F02364", "ACSettingIndex", 0)
) | ForEach-Object {
	Set-Registry -KeyPath $_[0] -PropertyName $_[1] -PropertyValue $_[2]
}

Write-Status "Disabling the Windows Desktop Update Active Setup"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{89820200-ECBD-11cf-8B85-00AA005B4340}" -PropertyName "StubPath" -Delete

Write-Status "Disabling the Background Layout Service"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OptimalLayout" -PropertyName "EnableAutoLayout" -PropertyValue 0

Write-Status "Setting an undocumented setting to increase the logon time"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -PropertyName "DelayedDesktopSwitchTimeout" -PropertyValue 1

Write-Status "Remove Folder Redirection delay (may not be relevant)"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -PropertyName "FolderRedirectionWait" -PropertyValue 0

Write-Status "Hide fast user switching option"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -PropertyName "HideFastUserSwitching" -PropertyValue 1

Write-Status "Disabling 'Last Access' timestamp on filesystem"
Start-ExternalProcess -Executable "fsutil" -Arguments "behavior set DisableLastAccess 1"

Write-Status "Disabling Boot Optimization"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Microsoft\Dfrg\BootOptimizeFunction" -PropertyName "Enable" -PropertyValue "N"

Write-Status "Disabling WinSxS ResetBase"
Set-Registry -KeyPath "HKLM:\Software\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" -PropertyName "DisableResetbase" -PropertyValue 0

Write-Status "Disabling Crash Drump"
Set-Registry -KeyPath "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" -PropertyName "CrashDumpEnabled" -PropertyValue 0

Write-Status "Disabling Storage Sense"
Set-Registry -KeyPath "HKLM:\Software\Policies\Microsoft\Windows\StorageSense" -PropertyName "AllowStorageSenseGlobal" -PropertyValue 0

Write-Status "Disabling the WMI Reliability Provider"
Set-Registry -KeyPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Reliability Analysis\WMI" -PropertyName "WMIEnable" -PropertyValue 0
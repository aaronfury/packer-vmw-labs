Import-Module -Name ".\BuildFunctions.psm1"

# Disable UAC
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

Write-Status "Disabling UAC"
$Properties = @{
	"EnableLUA" = 0;
	"ConsentPromptBehaviorAdmin" = 0;
	"ConsentPromptBehaviorUser" = 3;
	"EnableInstallerDetection" = 1;
	"EnableVirtualization" = 1;
	"PromptOnSecureDesktop" = 0;
	"ValidateAdminCodeSignature" = 0;
	"FilterAdministratorToken" = 0;
}

Set-Registry -KeyPath $RegPath -PropertyHash $Properties

# Remove unnecessary features
$FeaturesToRemove = @(
	"PowerShell-V2",
	"Windows-Defender",
	"XPS-Viewer"
)

Write-Status "Uninstalling Windows features - $($FeaturesToRemove -join ", ")"
try {
	[void](Uninstall-WindowsFeature -Name $FeaturesToRemove -Restart:$false -Remove)
} catch {
	Write-Status "Unable to remove features" $_
}

Write-Status "Disabling Internet Explorer"
try {
	[void](Disable-WindowsOptionalFeature -Online -FeatureName "Internet-Explorer-Optional-amd64" -NoRestart -Remove)
} catch {
	Write-Status "Failed to disable the Internet Explorer Optional Feature" $_
}
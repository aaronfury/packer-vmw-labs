# Create Accounts
# Description: This will create any accounts needed by the image.
# OS: Any Windows
# Notes: The password is set at build time by terraform.  The password is also set to never expire.

Import-Module -Name "C:\Temp\BuildFunctions.psm1"

$UserPass = $env:USERPASS
$UserIsAdmin = [bool]$env:USERISADMIN
$UserUsername = $env:USERNAME
$UserFullname = $env:USERFULLNAME

Write-Status "Creating $UserUsername account"
try {
	[void](New-LocalUser -Name $UserUsername -FullName $UserFullname -Password (ConvertTo-SecureString -AsPlainText -Force -String $UserPass) -PasswordNeverExpires:$true)
} catch {
	Write-Status "Failed to create $UserUsername" $_
}

if ( $UserIsAdmin ) {
	try {
		Write-Substatus "Adding $UserUsername to local Administrators group"
		[void](Add-LocalGroupMember -Group "Administrators" -Member $UserUsername)
	} catch {
		Write-Status "Failed to add $UserUsername to local Administrators group" $_
	}
} else {
	try {
		Write-Substatus "Adding $UserUsername to local Users group"
		[void](Add-LocalGroupMember -Group "Users" -Member $UserUsername)
	} catch {
		Write-Status "Failed to add $UserUsername to local Users group" $_
	}
}
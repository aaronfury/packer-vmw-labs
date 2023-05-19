$vars = @{
	"winrm_username" = "administrator";
	"winrm_password" = "Password123!";
}

$varSplat = "";
foreach ($key in $vars.Keys) {
	$varSplat += "-var `"$key=$($vars[$key])`" "
}

# Download Packer plugins
.\packer.exe init ".\images\win-2022-base\main.pkr.hcl"


# Packer build
.\packer.exe build -force -var-file=".\images\win-2022-base\base.auto.pkrvars.hcl" $varSplat ".\images\win-2022-base\main.pkr.hcl"